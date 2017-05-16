#!/bin/bash

# Script to either save JSS config via api to XML or upload that XML to a new JSS

# Loosely based on the work by Jeffrey Compton at
# https://github.com/igeekjsc/JSSAPIScripts/blob/master/jssMigrationUtility.bash
# His hard work is acknowledged and gratefully used. (and abused).

# Author      : richard@richard-purves.com
# Version 0.1 : 10-07-2017 - Initial Version
# Version 0.2 : 15-07-2017 - Download works. Misses out empty items. Upload still fails hard.
# Version 0.3 : 16-07-2017 - Upload code in test. Improvements to UI. Code simplification.
# Version 0.4 : 16-07-2017 - Skips empty JSS categories on download. Properly archives existing download. Choice of storage location for xml files.
# Version 0.5 : 16-07-2017 - Upload code testing competion

# Set up variables here
export resultInt=1
export currentver="0.5"
export currentverdate="16th May 2017"

# These are the categories we're going to save and process
declare -a jssitem
jssitem[0]="sites"							# Backend configuration
jssitem[1]="categories"
jssitem[2]="ldapservers"
jssitem[3]="accounts"
jssitem[4]="buildings"
jssitem[5]="departments"
jssitem[6]="directorybindings"
jssitem[7]="removablemacaddresses"
jssitem[8]="netbootservers"
jssitem[9]="distributionpoints"
jssitem[10]="softwareupdateservers"
jssitem[11]="networksegments"
jssitem[12]="healthcarelistener"
jssitem[13]="ibeacons"
jssitem[14]="infrastructuremanager"
jssitem[15]="peripherals"
jssitem[16]="peripheraltypes"
jssitem[17]="smtpserver"
jssitem[18]="vppaccounts"
jssitem[19]="vppassignments"
jssitem[20]="vppinvitations"
jssitem[21]="webhooks"
jssitem[22]="diskencryptionconfigurations"
jssitem[23]="allowedfileextensions"
jssitem[24]="ebooks"
jssitem[25]="computerextensionattributes" 	# Computer configuration
jssitem[26]="dockitems"
jssitem[27]="printers"
jssitem[28]="licensedsoftware"
jssitem[29]="scripts"
jssitem[30]="restrictedsoftware"
jssitem[31]="computergroups"
jssitem[32]="osxconfigurationprofiles"
jssitem[33]="macapplications"
jssitem[34]="managedpreferenceprofiles"
jssitem[35]="packages"
jssitem[36]="policies"
jssitem[37]="advancedcomputersearches"
jssitem[38]="patches"
jssitem[39]="mobiledevicegroups"			# Mobile configuration
jssitem[40]="mobiledeviceapplications"
jssitem[41]="mobiledeviceconfigurationprofiles"
jssitem[42]="mobiledeviceenrollmentprofiles"
jssitem[43]="mobiledeviceextensionattributes"
jssitem[44]="mobiledeviceprovisioningprofiles"
jssitem[45]="classes"
jssitem[46]="advancedmobiledevicesearches"
jssitem[47]="userextensionattributes"		# User configuration
jssitem[48]="usergroups"
jssitem[49]="users"
jssitem[50]="advancedusersearches"

# Start functions here
doesxmlfolderexist()
{
	# Check and create the JSS xml folder and archive folders if missing.
	[ ! -d "$xmlloc" ] && mkdir -p "$xmlloc"
	[ ! -d "$xmlloc"/archives ] && mkdir -p "$xmlloc"/archives

	# Check for existing items, archiving if necessary.
	for (( loop=0; loop<${#jssitem[@]}; loop++ ))
	do
		if [ -d "$xmlloc"/"${jssitem[$loop]}" ]
		then
			ditto -ck "$xmlloc"/"${jssitem[$loop]}" "$xmlloc"/archives/"${jssitem[$loop]}"-$( date +%Y%m%d%H%M%S ).zip
			rm -rf "$xmlloc/${jssitem[$loop]}"
		fi

	# Check and create the JSS xml resource folders if missing.
		mkdir -p "$xmlloc/${jssitem[$loop]}"
		mkdir -p "$xmlloc/${jssitem[$loop]}/id_list"
		mkdir -p "$xmlloc/${jssitem[$loop]}/fetched_xml"
		mkdir -p "$xmlloc/${jssitem[$loop]}/parsed_xml"
	done
}

getjssserverdetails()
{
	read -p "Enter the originating JSS server address (https://www.example.com:8443) : " jssaddress
	read -p "Enter the originating JSS server api username : " jssapiuser
	read -p "Enter the originating JSS api user password : " -s jssapipwd
	export origjssaddress=$jssaddress
	export origjssapiuser=$jssapiuser
	export origjssapipwd=$jssapipwd
	echo -e "\n"
	read -p "Enter the destination JSS server address (https://example.jamfcloud.com:443) : " jssaddress
	read -p "Enter the destination JSS server api username : " jssapiuser
	read -p "Enter the destination JSS api user password : " -s jssapipwd
	export destjssaddress=$jssaddress
	export destjssapiuser=$jssapiuser
	export destjssapipwd=$jssapipwd

	# Ask which instance we need to process, check if it exists and go from there
	echo -e "\n"
	echo "Enter the destination JSS instance name to upload"
	read -p "(Or enter for a non-context JSS) : " jssinstance

	# Check for the skip
	if [[ $jssinstance != "" ]];
	then
		jssinstance="/$instance/"
	fi

	# Where shall we store all this lovely xml?
	echo -e "\n"
	echo "Please enter the path to store data"
	read -p "(Or enter to use $HOME/Desktop) : " xmlloc

	# Check for the skip
#	if [[ $path = "" ]];
#	then
		export xmlloc="/Users/Shared/JSS_Config"
#	fi
}

grabexistingjssxml()
{
	# Setting IFS Env to only use new lines as field seperator 
	OIFS=$IFS
	IFS=$'\n'

	# Loop around the array of JSS categories we set up earlier.
	for (( loop=0; loop<${#jssitem[@]}; loop++ ))
	do	
		# Set our result incremental variable to 1 (just so we can reset and rerun this section without quitting the script)
		export resultInt=1

		# Work out where things are going to be stored on this loop
		export formattedList=$xmlloc/${jssitem[$loop]}/id_list/formattedList.xml
		export plainList=$xmlloc/${jssitem[$loop]}/id_list/plainList
		export plainListAccountsUsers=$xmlloc/${jssitem[$loop]}/id_list/plainListAccountsUsers
		export plainListAccountsGroups=$xmlloc/${jssitem[$loop]}/id_list/plainListAccountsGroups
		export fetchedResult=$xmlloc/${jssitem[$loop]}/fetched_xml/result"$resultInt".xml
		export fetchedResultAccountsUsers=$xmlloc/${jssitem[$loop]}/fetched_xml/userResult"$resultInt".xml
		export fetchedResultAccountsGroups=$xmlloc/${jssitem[$loop]}/fetched_xml/groupResult"$resultInt".xml	
	
		# Grab all existing ID's for the current category we're processing
		echo -e "\n\nCreating ID list for ${jssitem[$loop]} on template JSS \n"
		curl -s -k $origjssaddress/JSSResource/${jssitem[$loop]} --user "$origjssapiuser:$origjssapipwd" | xmllint --format - > $formattedList

		if [ ${jssitem[$loop]} = "accounts" ];
		then
			if [ `cat "$formattedList" | grep "<users/>" | wc -l | awk '{ print $1 }'` = "0" ];
			then
				echo "Creating plain list of user ID's..."
				cat $formattedList | sed '/<site>/,/<\/site>/d' | sed '/<groups>/,/<\/groups>/d' | awk -F '<id>|</id>' '/<id>/ {print $2}' > $plainListAccountsUsers
			else
				rm $formattedList
			fi

			if  [ `cat "$formattedList" | grep "<groups/>" | wc -l | awk '{ print $1 }'` = "0" ];
			then
				echo "Creating plain list of group ID's..."
				cat $formattedList | sed '/<site>/,/<\/site>/d'| sed '/<users>/,/<\/users>/d' | awk -F '<id>|</id>' '/<id>/ {print $2}' > $plainListAccountsGroups
			else
				rm $formattedList
			fi
		else
			if [ `cat "$formattedList" | grep "<size>0" | wc -l | awk '{ print $1 }'` = "0" ];
			then
				echo -e "\n\nCreating a plain list of ${jssitem[$loop]} ID's \n"
				cat $formattedList |awk -F'<id>|</id>' '/<id>/ {print $2}' > $plainList
			else
				rm $formattedList
			fi
		fi

		# Work out how many ID's are present IF formattedlist is present. Grab and download each one for the specific search we're doing. Special code for accounts because the API is annoyingly different from the rest.
		if [ -f "$formattedList" ];
		then
			case "${jssitem[$loop]}" in
				accounts)
					totalFetchedIDsUsers=$( cat "$plainListAccountsUsers" | wc -l | sed -e 's/^[ \t]*//' )
					for userID in $( cat $plainListAccountsUsers )
					do
						echo "Downloading User ID number $userID ( $resultInt out of $totalFetchedIDsUsers )"
						fetchedResultAccountsUsers=$( curl --silent -k --user "$origjssapiuser:$origjssapipwd" -H "Content-Type: application/xml" -X GET "$origjssaddress/JSSResource/${jssitem[$loop]}/userid/$userID" | xmllint --format - )
						itemID=$( echo "$fetchedResultAccountsUsers" | grep "<id>" | awk -F '<id>|</id>' '{ print $2; exit; }')
						itemName=$( echo "$fetchedResultAccountsUsers" | grep "<name>" | awk -F '<name>|</name>' '{ print $2; exit; }')
						cleanedName=$( echo "$itemName" | sed 's/[:\/\\]//g' )
						fileName="$cleanedName [ID $itemID]"
						echo "$fetchedResultAccountsUsers" > $xmlloc/${jssitem[$loop]}/fetched_xml/user_"$resultInt.xml"
					
						let "resultInt = $resultInt + 1"
					done

					resultInt=1

					totalFetchedIDsGroups=$( cat "$plainListAccountsGroups" | wc -l | sed -e 's/^[ \t]*//' )
					for groupID in $( cat $plainListAccountsGroups )
					do
						echo "Downloading Group ID number $groupID ( $resultInt out of $totalFetchedIDsGroups )"
						fetchedResultAccountsGroups=$( curl --silent -k --user "$origjssapiuser:$origjssapipwd" -H "Content-Type: application/xml" -X GET "$origjssaddress/JSSResource/${jssitem[$loop]}/groupid/$groupID" | xmllint --format - )
						itemID=$( echo "$fetchedResultAccountsGroups" | grep "<id>" | awk -F '<id>|</id>' '{ print $2; exit; }')
						itemName=$( echo "$fetchedResultAccountsGroups" | grep "<name>" | awk -F '<name>|</name>' '{ print $2; exit; }')
						cleanedName=$( echo "$itemName" | sed 's/[:\/\\]//g' )
						fileName="$cleanedName [ID $itemID]"
						echo "$fetchedResultAccountsGroups" > $xmlloc/${jssitem[$loop]}/fetched_xml/group_"$resultInt.xml"
					
						let "resultInt = $resultInt + 1"
					done			
				;;
			
				*)
					totalFetchedIDs=`cat "$plainList" | wc -l | sed -e 's/^[ \t]*//'`

					for apiID in $(cat $plainList)
					do
						echo "Downloading ID number $apiID ( $resultInt out of $totalFetchedIDs )"
						curl -s -k --user "$origjssapiuser:$origjssapipwd" -H "Content-Type: application/xml" -X GET "$origjssaddress/JSSResource/${jssitem[$loop]}/id/$apiID" | xmllint --format - > $fetchedResult
						resultInt=$(($resultInt + 1))
						fetchedResult=$xmlloc/${jssitem[$loop]}/fetched_xml/result"$resultInt".xml
					done	
				;;
			esac
			
			# Depending which category we're dealing with, parse the grabbed files into something we can upload later.
			case "${jssitem[$loop]}" in	
				computergroups)
					echo -e "\nParsing JSS computer groups"

					for resourceXML in $(ls $xmlloc/${jssitem[$loop]}/fetched_xml)
					do
						echo "Parsing computer group: $resourceXML"

						if [[ `cat $xmlloc/${jssitem[$loop]}/fetched_xml/$resourceXML | grep "<is_smart>false</is_smart>"` ]]
						then
							echo "$resourceXML is a static computer group"
							cat $xmlloc/${jssitem[$loop]}/fetched_xml/$resourceXML | grep -v "<id>" | sed '/<computers>/,/<\/computers/d' > $xmlloc/${jssitem[$loop]}/parsed_xml/static_group_parsed_"$resourceXML"
						else
							echo "$resourceXML is a smart computer group..."
							cat $xmlloc/${jssitem[$loop]}/fetched_xml/$resourceXML | grep -v "<id>" | sed '/<computers>/,/<\/computers/d' > $xmlloc/${jssitem[$loop]}/parsed_xml/smart_group_parsed_"$resourceXML"
						fi					
					done
				;;

				policies|restrictedsoftware)
					echo -e "\nParsing ${jssitem[$loop]}"

					for resourceXML in $(ls $xmlloc/${jssitem[$loop]}/fetched_xml)
					do
						echo "Parsing policy: $resourceXML"
			
						if [[ `cat $xmlloc/${jssitem[$loop]}/fetched_xml/$resourceXML | grep "<name>No category assigned</name>"` ]]
						then
							echo "Policy $resourceXML is not assigned to a category. Ignoring."
						else
							echo "Processing policy file $resourceXML ."
							cat $xmlloc/${jssitem[$loop]}/fetched_xml/$resourceXML | grep -v "<id>" | sed '/<computers>/,/<\/computers>/d' | sed '/<self_service_icon>/,/<\/self_service_icon>/d' | sed '/<limit_to_users>/,/<\/limit_to_users>/d' | sed '/<users>/,/<\/users>/d' | sed '/<user_groups>/,/<\/user_groups>/d' > $xmlloc/${jssitem[$loop]}/parsed_xml/parsed_"$resourceXML"
						fi
					done
				;;

				*)
					echo -e "\nNo special parsing needed for: ${jssitem[$loop]}. Removing references to ID's\n"

					for resourceXML in $(ls $xmlloc/${jssitem[$loop]}/fetched_xml)
					do
						echo "Parsing $resourceXML"
						cat $xmlloc/${jssitem[$loop]}/fetched_xml/$resourceXML | grep -v "<id>" > $xmlloc/${jssitem[$loop]}/parsed_xml/parsed_"$resourceXML"
					done
				;;
			esac
		else
			echo -e "\nResource ${jssitem[$loop]} empty. Skipping."
		fi
	done
	
	# Setting IFS back to default 
	IFS=$OIFS
}

puttonewjss()
{
	# Setting IFS Env to only use new lines as field seperator 
	OIFS=$IFS
	IFS=$'\n'

	for (( loop=0; loop<${#jssitem[@]}; loop++ ))
	do
		echo -e "\nPosting ${jssitem[$loop]} to new JSS instance: $destjssaddress$jssinstance"
		
		case "$jssitem[$loop]" in
			accounts)	
				echo "Posting user accounts."

				totalParsedResourceXML_user=$( ls "$xmlloc/${jssitem[$loop]}"/parsed_xml/user* | wc -l | sed -e 's/^[ \t]*//' )
				postInt_user=0	

				for xmlPost_user in $( ls "$xmlloc/${jssitem[$loop]}"/parsed_xml/user* )
				do
					let "postInt_user = $postInt_user + 1"
					echo -e "\n----------\n----------"
					echo -e "\nPosting $parsedXML_user ( $postInt_user out of $totalParsedResourceXML_user ) \n"
					curl -k -g "$destjssaddress/JSSResource/${jssitem[$loop]}/userid/0" --user "$destinationJSSuser:$destinationJSSpw" -H "Content-Type: application/xml" -X POST -d "$xmlPost_user"
				done

				echo "Posting user group accounts."

				totalParsedResourceXML_group=$( ls "$xmlloc/${jssitem[$loop]}"/parsed_xml/group* | wc -l | sed -e 's/^[ \t]*//' )
				postInt_group=0	

				for xmlPost_group in $( ls "$xmlloc/${jssitem[$loop]}"/parsed_xml/group* )
				do
					let "postInt_group = $postInt_group + 1"
					echo -e "\n----------\n----------"
					echo -e "\nPosting $parsedXML_group ( $postInt_group out of $totalParsedResourceXML_group ) \n"
					curl -k -g "$destjssaddress/JSSResource/${jssitem[$loop]}/groupid/0" --user "$destinationJSSuser:$destinationJSSpw" -H "Content-Type: application/xml" -X POST -d "$xmlPost_group"
				done
			;;	
				
			computergroups)
				echo "Posting static computer groups."

				totalParsedResourceXML_staticGroups=$(ls $xmlloc/${jssitem[$loop]}/parsed_xml/static_group_parsed* | wc -l | sed -e 's/^[ \t]*//')
				postInt_static=0

				for parsedXML_static in $(ls $xmlloc/${jssitem[$loop]}/parsed_xml/static_group_parsed*)
				do
					xmlPost_static=`cat $parsedXML_static`
					let "postInt_static = $postInt_static + 1"
					echo "Posting $parsedXML_static ( $postInt_static out of $totalParsedResourceXML_staticGroups )"
					curl -s -k "$destjssaddress/JSSResource/${jssitem[$loop]}/id/0" --user "$destjssapiuser:$destjssapipwd" -H "Content-Type: application/xml" -X POST -d "$xmlPost_static"
				done

				echo "Posting smart computer groups"

				totalParsedResourceXML_smartGroups=$(ls $xmlloc/${jssitem[$loop]}/parsed_xml/smart_group_parsed* | wc -l | sed -e 's/^[ \t]*//')
				postInt_smart=0	

				for parsedXML_smart in $(ls $xmlloc/${jssitem[$loop]}/parsed_xml/smart_group_parsed*)
				do
					xmlPost_smart=`cat $parsedXML_smart`
					let "postInt_smart = $postInt_smart + 1"
					echo "Posting $parsedXML_smart ( $postInt_smart out of $totalParsedResourceXML_smartGroups )"
					curl -s -k "$destjssaddress/JSSResource/${jssitem[$loop]}/id/0" --user "$destjssapiuser:$destjssapipwd" -H "Content-Type: application/xml" -X POST -d "$xmlPost_smart"
				done
			;;
		
			*)
				totalParsedResourceXML=$(ls $xmlloc/${jssitem[$loop]}/parsed_xml | wc -l | sed -e 's/^[ \t]*//')
				postInt=0	

				for parsedXML in $(ls $xmlloc/${jssitem[$loop]}/parsed_xml)
				do
					xmlPost=`cat $xmlloc/${jssitem[$loop]}/parsed_xml/$parsedXML`
					let "postInt = $postInt + 1"
					echo -e "\nPosting $parsedXML ( $postInt out of $totalParsedResourceXML ) \n"
					curl -s -k "$destjssaddress/JSSResource/${jssitem[$loop]}/id/0" --user "$destjssapiuser:$destjssapipwd" -H "Content-Type: application/xml" -X POST -d "$xmlPost"
				done
			;;
		esac
	done

	# Setting IFS back to default 
	IFS=$OIFS
}

MainMenu()
{
	# Set IFS to only use new lines as field separator.
	OIFS=$IFS
	IFS=$'\n'

	# Start menu screen here
	echo -e "\n----------------------------------------"
	echo -e "\n          JSS Config in a Box"
	echo -e "\n----------------------------------------"
	echo -e "    Version $currentver - $currentverdate"
	echo -e "----------------------------------------\n"

	while [[ $choice != "q" ]]
	do
		echo -e "\nMain Menu\n"
		echo -e "1) Grab config from template JSS"
		echo -e "2) Upload config to new JSS instance"

		echo -e "q) Quit!\n"

		read -p "Choose an option (1-2 / q) : " choice

		case "$choice" in
			1)
				grabexistingjssxml ;;
			2)
				puttonewjss ;;
			q)
				echo -e "\nThank you for using JSS Config in a Box!"
				;;
			*)
				echo -e "\nIncorrect input. Please try again." ;;
		esac
		
	done
	
	# Setting IFS back to default 
	IFS=$OIFS
}

# Call functions to make this work here
doesxmlfolderexist
getjssserverdetails
MainMenu

# All done!
exit 0
