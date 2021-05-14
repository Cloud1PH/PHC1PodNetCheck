#!/bin/bash

# Pre-requirements

#get the filename of this script when it starts to run
_self="${0##*/}"

#Checking for root permissions
if [[ $(/usr/bin/id -u) -ne 0 ]]; then
	echo You are not running as the root user.  Please try again with root privileges.;
	logger -t You are not running as the root user.  Please try again with root privileges.;
	exit 1;
fi;

#pre-variables
registryURL=$1
choice=$2

# URLs List for Function B and C
SmCurls=("dstf.trendmicro.com" "container.us-1.cloudone.trendmicro.com" "licenseupdate.trendmicro.com" "ipv6-iaus.trendmicro.com" "telemetry.deepsecurity.trendmicro.com" "dssc10.icrc.trendmicro.com" "dssc10-en-f.trx.trendmicro.com") #SPN Urls pending
CSurls=("container.us-1.cloudone.trendmicro.com" "telemetry.deepsecurity.trendmicro.com")

#define variable for dnsutils detection, set to 0 to make script defaut function to not delete dnsutils pod unless verified that script deployed dnsutils pod for safety
deletelater=0

##############################################################################################################################################################

#Functions

Help()
{
   # Display Help
   echo
   echo "PH Cloud One Kubernetes Connectivity Checker Tool for Smart Check and Container Security Commands!"
   echo
   echo "Disclaimer: The Tool will deploy a dnsutils pod using https://k8s.io/examples/admin/dns/dnsutils.yaml if no exisiting pod is detected for testing purposes. The created dnsutils pod will be deleted after the tool operation is done."
   echo
   echo "======================================================"
   echo
   echo "SYNTAX"
   echo "- Syntax (if you are in the current directory): ./$_self [(optional) registryURL] [choice]"
   echo "- Sample syntax: ./$_self registryurl:443 A"
   echo "- Specifying the registry URL only will run A, B, and C. No arguments will result in running B and C."
   echo
   echo "======================================================"
   echo
   echo "Options in the second argument (choice):"
   echo
   echo "A     run A - Test Connection to Registry (needs registry URL as first argurment.)"
   echo "B     run B - Test connection to C1-CS/SPN for DSSC"
   echo "C     run C - Test Connection to C1-CS for Admission Controller"
   echo "-help     Print help for commands."
   echo
}

#the function which is to set the input on which of the functions should run inside the controller logic.
ChooseOption(){
    echo
    echo
    echo "Functions:"
    echo "A     run A - Test Connection to Registry"
    echo "B     run B - Test connection to C1-CS/SPN for DSSC"
    echo "C     run C - Test Connection to C1-CS for Admission Controller"
    echo
    #echo
	#echo "Please choose which functions to run on below options:"
	#echo "a.) run A, B, C"
	#echo "b.) run B, C"
	#echo "c.) run A"
	#echo "d.) run B"
	#echo "e.) run C"
	#echo "Option to run:"
    #echo
	#echo "Option to run:" >> /tmp/SC-CS_Pre-Check/connection.txt
    echo >> /tmp/SC-CS_Pre-Check/connection.txt


	if [[ -n $registryURL && ${#registryURL} -gt 1 && -z $choice ]]; then
		input="a"
		#echo -e $input
		checkdnsutils
	elif [[ -z $registryURL && -z $choice ]]; then
		input="b"
		#echo -e $input
		checkdnsutils
	elif [[ -n $registryURL && $choice == "A" ]]; then
		input="c"
		#echo -e $input
		checkdnsutils
	elif [[ ${#registryURL} -le 2 && ${#registryURL} -gt 0 && -z $choice && $registryURL == "B" ]]; then
		input="d"
		#echo -e $input
		checkdnsutils
	elif [[ ${#registryURL} -le 2 && ${#registryURL} -gt 0 && -z $choice && $registryURL == "C" ]]; then
		input="e"
		#echo -e $input
		checkdnsutils
	else
		echo -e "Wrong input in the argument. Try again and consult -help if needed."
		echo -e "Wrong input in the argument. Try again and consult -help if needed." >> /tmp/SC-CS_Pre-Check/connection.txt
		exit 1;
	fi

}

#kubectl checker
CheckK8(){
    echo
	echo "======================================================"
    echo > /tmp/SC-CS_Pre-Check/connection.txt
	echo "======================================================" >> /tmp/SC-CS_Pre-Check/connection.txt
    date=$(date)
    echo "Timestamp: $date"
    echo "Timestamp: $date" >> /tmp/SC-CS_Pre-Check/connection.txt
	echo
    echo >> /tmp/SC-CS_Pre-Check/connection.txt
	echo "PH Cloud One Kubernetes Connectivity Checker Tool for Smart Check and Container Security"
	echo "PH Cloud One Kubernetes Connectivity Checker Tool for Smart Check and Container Security" >> /tmp/SC-CS_Pre-Check/connection.txt
	echo
	echo >> /tmp/SC-CS_Pre-Check/connection.txt

	echo -e "Checking if kubectl is installed and working..."
	echo -e "Checking if kubectl is installed and working..." >> /tmp/SC-CS_Pre-Check/connection.txt
	echo
	echo >> /tmp/SC-CS_Pre-Check/connection.txt

	#This is to check if the kubectl prints out successful attempt (Client and Server)
	checkk8ctl=$(kubectl version &> /dev/null && echo "Working" || echo "Not Working")
	if [[ $checkk8ctl == "Working" ]]; then
		echo -e "kubectl is working!"
		echo -e "kubectl is working!" >> /tmp/SC-CS_Pre-Check/connection.txt
		echo
		echo >> /tmp/SC-CS_Pre-Check/connection.txt
		#after checking (if successful), it will now call the function needed for the controller logic)
		ChooseOption
	else
		echo -e "kubectl is not properly installed, please make sure no error/warning to be found when kubectl is being executed then run again the tool. Thank you!"
		echo -e "kubectl is not properly installed, please make sure no error/warning to be found when kubectl is being executed then run again the tool. Thank you!" >> /tmp/SC-CS_Pre-Check/connection.txt
		exit 1;
	fi

}


##########CHECK OR DEPLOY DNSUTILS###############

#function to detect dnsutils pod
checkdnsutils(){
	echo
	echo "Checking if dnsutils Pod already exists..."
	echo
	echo "Checking if dnsutils Pod already exists..." >> /tmp/SC-CS_Pre-Check/connection.txt
	echo >> /tmp/SC-CS_Pre-Check/connection.txt
	
	DNSUTILS_DETECT=$(kubectl get pods | grep dnsutils | awk '{print $1}')
	echo "dnsutils detection output: $DNSUTILS_DETECT" >> /tmp/SC-CS_Pre-Check/connection.txt

	if [ "$DNSUTILS_DETECT" == "dnsutils" ]; then
		echo "Pod name dnsutils already exists, will use existing Pod for connection testing..."
		echo
		echo "Pod name dnsutils already exists, will use existing Pod for connection testing..." >> /tmp/SC-CS_Pre-Check/connection.txt
		echo >> /tmp/SC-CS_Pre-Check/connection.txt
	
	else
		deletelater=1
        echo "No existing dnsutils pod detected! Will deploy a new dnsutils pod!"
        echo "No existing dnsutils pod detected! Will deploy a new dnsutils pod!" >> /tmp/SC-CS_Pre-Check/connection.txt
        echo 
        echo >> /tmp/SC-CS_Pre-Check/connection.txt 
		#echo "Delete created dnsutils pod later: $deletelater"
		#echo
		#echo "Delete created dnsutils pod later: $deletelater" >> /tmp/SC-CS_Pre-Check/connection.txt
		#echo >> /tmp/SC-CS_Pre-Check/connection.txt
		deploydnsutils
	fi
}

#function to deploy dnsutils pod
deploydnsutils(){
	
	#deploy and wait dnsutils pod
	echo "Deploying dnsutils pod..."
    echo "Deploying dnsutils pod..." >> /tmp/SC-CS_Pre-Check/connection.txt
	echo
	deploy=$(kubectl apply -f https://k8s.io/examples/admin/dns/dnsutils.yaml && kubectl wait --for condition=ready --timeout=60s -f https://k8s.io/examples/admin/dns/dnsutils.yaml)
	exitcode=$(echo $?)
	echo "$deploy"
	echo
	echo "$deploy" >> /tmp/SC-CS_Pre-Check/connection.txt
	echo >> /tmp/SC-CS_Pre-Check/connection.txt

	echo "deploy dnsutils pod exit code: $exitcode" >> /tmp/SC-CS_Pre-Check/connection.txt
	echo >> /tmp/SC-CS_Pre-Check/connection.txt

	if [ $exitcode -ne 0 ]; then
		echo "Failed to deploy or dnsutils Pod still pending after 1 minute. Use command 'kubectl get pods' to see dnsutils pod status"
		echo
		echo "Failed to deploy or dnsutils Pod still pending after 1 minute. Use command 'kubectl get pods' to see dnsutils pod status" >> /tmp/SC-CS_Pre-Check/connection.txt
		echo >> /tmp/SC-CS_Pre-Check/connection.txt
		echo "Script exiting..."
		echo
		echo "Script exiting..." >> /tmp/SC-CS_Pre-Check/connection.txt
		echo /tmp/SC-CS_Pre-Check/connection.txt
		exit

	else
		echo "dnsutils pod successfully deployed!"
		echo
		echo "dnsutils pod successfully deployed!" >> /tmp/SC-CS_Pre-Check/connection.txt
		echo >> /tmp/SC-CS_Pre-Check/connection.txt

	fi

}

#delete dnsutils pod
deletednsutils(){
    echo
    echo >> /tmp/SC-CS_Pre-Check/connection.txt
    echo "Deleting created dnsutils pod..." 
    echo "Deleting created dnsutils pod..." >> /tmp/SC-CS_Pre-Check/connection.txt


	delete=$(kubectl delete pod dnsutils --timeout=60s)

	exitcode=$(echo $?)
	echo
	echo >> /tmp/SC-CS_Pre-Check/connection.txt
	echo "delete dnsutils pod exit code: $exitcode" >> /tmp/SC-CS_Pre-Check/connection.txt
	echo >> /tmp/SC-CS_Pre-Check/connection.txt

	if [ $exitcode -ne 0 ]; then
		echo "Failed to delete or still pending after 1 minute. Use command 'kubectl get pods' to see dnsutils pod status"
		echo
		echo "Failed to delete or still pending after 1 minute. Use command 'kubectl get pods' to see dnsutils pod status" >> /tmp/SC-CS_Pre-Check/connection.txt
		echo >> /tmp/SC-CS_Pre-Check/connection.txt
		echo "Script exiting..."
		echo
		echo "Script exiting..." >> /tmp/SC-CS_Pre-Check/connection.txt
		echo >> /tmp/SC-CS_Pre-Check/connection.txt
		exit

	else
		echo "dnsutils pod succesfully deleted!"
		echo
		echo "dnsutils pod succesfully deleted!" >> /tmp/SC-CS_Pre-Check/connection.txt
		echo >> /tmp/SC-CS_Pre-Check/connection.txt

	fi

}

##########CHECK OR DEPLOY DNSUTILS END###############

#FUNCTION A - Test Connection to Registry

FunctionA(){

	#############PARSING REGISTRY URL###############
	#detect FQDN and PORT
	echo
	echo >> /tmp/SC-CS_Pre-Check/connection.txt
	echo "FUNCTION A - Test Connection to Registry" >> /tmp/SC-CS_Pre-Check/connection.txt
	echo "FUNCTION A - Test Connection to Registry"
	echo
	echo >> /tmp/SC-CS_Pre-Check/connection.txt
	FQDN=$(echo $registryURL | awk -F ":" '{print $1}')
	PORT=$(echo $registryURL | awk -F ":" '{print $2}')

	#determine if FQDN value is IP or not
	oct1=$(echo $FQDN | awk -F "." '{print $1}')
	oct2=$(echo $FQDN | awk -F "." '{print $2}')
	oct3=$(echo $FQDN | awk -F "." '{print $3}')
	oct4=$(echo $FQDN | awk -F "." '{print $4}')

	echo "oct1: $oct1 , oct2: $oct2 , oct3: $oct3 , oct4: $oct4" >> /tmp/SC-CS_Pre-Check/connection.txt
	
	if [[ $oct1 -ge 1 && $oct1 -le 255 ]] && [[ $oct2 -ge 1 && $oct2 -le 255 ]] && [[ $oct3 -ge 1 && $oct3 -le 255 ]] && [[ $oct4 -ge 1 && $oct4 -le 255 ]]; then
		entrytype="IP"
		echo "entry type: $entrytype" >> /tmp/SC-CS_Pre-Check/connection.txt

	else
		entrytype="notIP"
		echo "entry type: $entrytype" >> /tmp/SC-CS_Pre-Check/connection.txt
	
	fi

	#substitute port 443 if no port
	if [ -z $PORT ]; then
		PORT=443
	fi

	echo "FQDN: $FQDN" >> /tmp/SC-CS_Pre-Check/connection.txt
	echo "PORT: $PORT" >> /tmp/SC-CS_Pre-Check/connection.txt

	###############PARSE COMPLETE###################

	#Do not NSLOOKUP if entry is IP
	if [ $entrytype == "notIP" ]; then

		#nslookup test
		echo -e "\n"
		echo "======================================================"
		echo "Testing name resolution for $FQDN"
		echo "======================================================" >> /tmp/SC-CS_Pre-Check/connection.txt
		echo "Testing name resolution for $FQDN" >> /tmp/SC-CS_Pre-Check/connection.txt
		echo >> /tmp/SC-CS_Pre-Check/connection.txt
		NSLOOKUPREG=$(kubectl exec -i -t dnsutils -- nslookup $FQDN &> /dev/null && echo "Connected" || echo "Failed to Connect")
		if [[ $NSLOOKUPREG == "Connected" ]]; then
			echo "$NSLOOKUPREG"
			echo "$NSLOOKUPREG" >> /tmp/SC-CS_Pre-Check/connection.txt
			echo "======================================================"
		else
			echo "$NSLOOKUPREG"
			echo "$NSLOOKUPREG" >> /tmp/SC-CS_Pre-Check/connection.txt
			echo "======================================================"
		fi

	fi

	#netcat test
	echo -e "\n"
	echo "======================================================"
	echo "Testing network connection to $FQDN:$PORT"
	echo "======================================================" >> /tmp/SC-CS_Pre-Check/connection.txt
	echo "Testing network connection to $FQDN:$PORT" >> /tmp/SC-CS_Pre-Check/connection.txt
	echo >> /tmp/SC-CS_Pre-Check/connection.txt
	CONN2REG=$(kubectl exec -i -t dnsutils -- nc -z -v -w 2 $FQDN:$PORT &> /dev/null && echo "Connected" || echo "Failed to Connect")
	if [[ $CONN2REG == "Connected" ]]; then
		echo "$CONN2REG"
		echo "$CONN2REG" >> /tmp/SC-CS_Pre-Check/connection.txt
		echo "======================================================"

	else
		echo "$CONN2REG"
		echo "$CONN2REG" >> /tmp/SC-CS_Pre-Check/connection.txt
		echo "======================================================"

		########### Detect if DSSC is deployed ##############
		detectDSSC=$(helm list | grep deepsecurity-smartcheck | awk '{print $1}')
		if [ "$detectDSSC" == "deepsecurity-smartcheck" ]; then

			###########Get Network Policy ports###########
			c=0

			for entry in $(helm get values deepsecurity-smartcheck | grep -o "\- [0-9]*" | awk '{print $2}'); do
				eval "var$c=$entry";
				c=$((c+1));
			done
			###########Get Network Policy ports DONE###########

			##########Compare Network Policy Ports#############
			match=0


			while [ $c -gt 0 ];
			do
				if [ "$(eval "echo \${var${c}}")" == $PORT ]; then
					match=1
				fi

				c=$((c-1))
			done


			if [ $match == 0 ]; then
				echo "Network Policy for registry port not yet configured, you can check https://github.com/deep-security/smartcheck-helm#timeouts-attempting-to-connect-to-registry"
				echo "Network Policy for registry port not yet configured, you can check https://github.com/deep-security/smartcheck-helm#timeouts-attempting-to-connect-to-registry" >> /tmp/SC-CS_Pre-Check/connection.txt
			fi
		fi	

		########Compare Network Policy Ports DONE###########

	fi
}




#FUNCTION B - Test connection to C1-CS/SPN for DSSC

#ASmartcheck 
SmCChecker (){

	echo >> /tmp/SC-CS_Pre-Check/connection.txt
    echo
	echo "FUNCTION B - Test connection to C1-CS/SPN for DSSC"
	echo "FUNCTION B - Test connection to C1-CS/SPN for DSSC" >> /tmp/SC-CS_Pre-Check/connection.txt
    echo
    echo >> /tmp/SC-CS_Pre-Check/connection.txt
    echo "Checking for Smart Check URLs via port 443..."
    echo "Checking for Smart Check URLs via port 443..." >> /tmp/SC-CS_Pre-Check/connection.txt
    echo
    echo >> /tmp/SC-CS_Pre-Check/connection.txt
    sleep 2

    for ACURL in "${SmCurls[@]}"
			do
				ACList=$(kubectl exec -i -t dnsutils -- nc -z -v -w 2 $ACURL 443 &> /dev/null && echo "Online" || echo "Offline")
				if [[ $ACList == "Online" ]]; then
						echo -e "Successfully connected to $ACURL via TCP port 443" 
				        echo -e "Successfully connected to $ACURL via TCP port 443" >> /tmp/SC-CS_Pre-Check/connection.txt
				else
						echo -e "Failed to connect to $ACURL via TCP port 443"
				        echo -e "Failed to connect to $ACURL via TCP port 443" >> /tmp/SC-CS_Pre-Check/connection.txt
				fi
			done

    echo >> /tmp/SC-CS_Pre-Check/connection.txt
    echo
}


#FUNCTION C - Test Connection to C1-CS for Admission Controller

#Container Security
CSChecker (){

	echo >> /tmp/SC-CS_Pre-Check/connection.txt
    echo
	echo "FUNCTION C - Test Connection to C1-CS for Admission Controller"
	echo "FUNCTION C - Test Connection to C1-CS for Admission Controller" >> /tmp/SC-CS_Pre-Check/connection.txt
    echo
    echo >> /tmp/SC-CS_Pre-Check/connection.txt
    echo "Checking for Container Security URLs via port 443..."
    echo "Checking for Container Security URLs via port 443..." >> /tmp/SC-CS_Pre-Check/connection.txt
    echo
    echo >> /tmp/SC-CS_Pre-Check/connection.txt
    sleep 2

    for CSURL in "${CSurls[@]}"
			do
				CSList=$(kubectl exec -i -t dnsutils -- nc -z -v -w 2 $CSURL 443 &> /dev/null && echo "Online" || echo "Offline")
				if [[ $CSList == "Online" ]]; then
						echo -e "Successfully connected to $CSURL via TCP port 443"
				        echo -e "Successfully connected to $CSURL via TCP port 443" >> /tmp/SC-CS_Pre-Check/connection.txt
				else
						echo -e "Failed to connect to $CSURL via TCP port 443"
				        echo -e "Failed to connect to $CSURL via TCP port 443" >> /tmp/SC-CS_Pre-Check/connection.txt
				fi
			done
    echo >> /tmp/SC-CS_Pre-Check/connection.txt
    echo
}



##############################################################################################################################################################



#Main Program Execution

#if running the script with -help option, this logic will run just to show the help.
while getopts ":help" option; do
   case $option in
      h) # display Help
         Help
         exit;;
   esac
done

#creates directory for the log folder
sudo rm -rf /tmp/SC-CS_Pre-Check/
sudo mkdir /tmp/SC-CS_Pre-Check/


#clears the current console (tty) then runs the first function
clear
CheckK8

#controller logic that is dependent on the ChooseOption function.
case $input in  
	a)
        echo
        echo >> /tmp/SC-CS_Pre-Check/connection.txt
		echo "do Functions A, B, C"
		echo "do Functions A, B, C" >> /tmp/SC-CS_Pre-Check/connection.txt
		FunctionA
		SmCChecker
		CSChecker
		;;
	b)
        echo
        echo >> /tmp/SC-CS_Pre-Check/connection.txt    
		echo "do Functions B, C"
		echo "do Functions B, C" >> /tmp/SC-CS_Pre-Check/connection.txt
		SmCChecker
		CSChecker
		;;
	c)
        echo
        echo >> /tmp/SC-CS_Pre-Check/connection.txt
		echo "do Function A"
		echo "do Function A" >> /tmp/SC-CS_Pre-Check/connection.txt
		FunctionA
		;;
	d)
        echo
        echo >> /tmp/SC-CS_Pre-Check/connection.txt
		echo "do Function B"
		echo "do Function B" >> /tmp/SC-CS_Pre-Check/connection.txt
		SmCChecker
		;;
	e)
        echo
        echo >> /tmp/SC-CS_Pre-Check/connection.txt
		echo "do Function C"
		echo "do Function C" >> /tmp/SC-CS_Pre-Check/connection.txt
		CSChecker
		;;
esac

#determine if dnsutils pod has to be deleted by script or not
if [ $deletelater == 1 ]; then
	deletednsutils

fi

#end of the code
echo
echo >> /tmp/SC-CS_Pre-Check/connection.txt
echo -e "Thank you for using the tool!"
echo -e "Log file -> /tmp/SC-CS_Pre-Check/connection.txt"
echo -e "Thank you for using the tool!"	>> /tmp/SC-CS_Pre-Check/connection.txt
echo
exit 1;
