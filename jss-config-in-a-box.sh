#!/bin/bash

# Script to either save JSS config via api to XML or upload that XML to a new JSS

# Loosely based on the work by Jeffrey Compton at
# https://github.com/igeekjsc/JSSAPIScripts/blob/master/jssMigrationUtility.bash
# His hard work is acknowledged and gratefully used. (and abused).

# Author      : richard@richard-purves.com
# v0.1 : 10-07-2017 - Initial Version
# v0.2 : 15-07-2017 - Download works. Misses out empty items. Upload still fails hard.
# v0.3 : 16-07-2017 - Upload code in test. Improvements to UI. Code simplification.
# v0.4 : 16-07-2017 - Skips empty JSS categories on download. Properly archives existing download. Choice of storage location for xml files.
# v0.5 : 17-07-2017 - Debugged condition that "for some reason" tried to delete my entire machine. Nearly succeeded too.
#					- Skips empty categories now for a significant speed improvement. Upload mostly works at this point.
# v0.6 : 17-07-2017 - Check for existing xml. Creates folders if missing, archives existing files if required. Upload fails on a few things.
# v0.7 : 17-07-2017 - Edging closer towards release candidate status. API code seems happier. App layout work required next.
# v0.8 : 18-07-2017 - Mostly working. Fails on duplicate account name(s) (expected). Will upload App Store apps, but error if VPP isn't working (expected). Fails on policies that create accounts (huh?).
# v1.0 : 24-07-2017 - Upload/Download working. Archival of old data wasn't working.

# Set up variables here
export resultInt=1
export currentver="1.0"
export currentverdate="24th May 2017"

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
jssitem[23]="ebooks"
jssitem[24]="computerextensionattributes" 	# Computer configuration
jssitem[25]="dockitems"
jssitem[26]="printers"
jssitem[27]="licensedsoftware"
jssitem[28]="scripts"
jssitem[29]="computergroups"
jssitem[30]="restrictedsoftware"
jssitem[31]="osxconfigurationprofiles"
jssitem[32]="macapplications"
jssitem[33]="managedpreferenceprofiles"
jssitem[34]="packages"
jssitem[35]="policies"
jssitem[36]="advancedcomputersearches"
jssitem[37]="patches"
jssitem[38]="mobiledevicegroups"			# Mobile configuration
jssitem[39]="mobiledeviceapplications"
jssitem[40]="mobiledeviceconfigurationprofiles"
jssitem[41]="mobiledeviceenrollmentprofiles"
jssitem[42]="mobiledeviceextensionattributes"
jssitem[43]="mobiledeviceprovisioningprofiles"
jssitem[44]="classes"
jssitem[45]="advancedmobiledevicesearches"
jssitem[46]="userextensionattributes"		# User configuration
jssitem[47]="usergroups"
jssitem[48]="users"
jssitem[49]="advancedusersearches"

# Start functions here
doesxmlfolderexist()
{
	# Where shall we store all this lovely xml?
	echo -e "\nPlease enter the path to store data"
	read -p "(Or enter to use $HOME/Desktop/JSS_Config) : " xmlloc

	# Check for the skip
	if [[ $path = "" ]];
	then
		export xmlloc="$HOME/Desktop/JSS_Config"
	fi

	# Check and create the JSS xml folder and archive folders if missing.
	if [ ! -d "$xmlloc" ];
	then
		mkdir -p "$xmlloc"
		mkdir -p "$xmlloc"/archives
	else
		echo -e "\n"
		read -p "Do you wish to archive existing xml files? (Y/N) : " archive
		if [[ "$archive" = "y" ]] || [[ "$archive" = "Y" ]];
		then
			archive="YES"
		else
			archive="NO"
		fi
	fi
	
	# Check for existing items, archiving if necessary.
	for (( loop=0; loop<${#jssitem[@]}; loop++ ))
	do
		if [ "$archive" = "YES" ];
		then
			if [ `ls -1 "$xmlloc"/"${jssitem[$loop]}"/* 2>/dev/null | wc -l` -gt 0 ];
			then
				echo "Archiving category: "${jssitem[$loop]}
				ditto -ck "$xmlloc"/"${jssitem[$loop]}" "$xmlloc"/archives/"${jssitem[$loop]}"-$( date +%Y%m%d%H%M%S ).zip
				rm -rf "$xmlloc/${jssitem[$loop]}"
			fi
		fi

	# Check and create the JSS xml resource folders if missing.
		if [ ! -f "$xmlloc/${jssitem[$loop]}" ];
		then
			mkdir -p "$xmlloc/${jssitem[$loop]}"
			mkdir -p "$xmlloc/${jssitem[$loop]}/id_list"
			mkdir -p "$xmlloc/${jssitem[$loop]}/fetched_xml"
			mkdir -p "$xmlloc/${jssitem[$loop]}/parsed_xml"
		fi
	done
}

grabexistingjssxml()
{
	# Setting IFS Env to only use new lines as field seperator 
	OIFS=$IFS
	IFS=$'\n'

	# Loop around the array of JSS categories we set up earlier.
	for (( loop=0; loop<${#jssitem[@]}; loop++ ))
	do	
		# Set our result incremental variable to 1
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
		if [ `ls -1 "$xmlloc/${jssitem[$loop]}/id_list"/* 2>/dev/null | wc -l` -gt 0 ];
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
		if [ `ls -1 "$xmlloc"/"${jssitem[$loop]}"/parsed_xml/* 2>/dev/null | wc -l` -gt 0 ];
		then
			# Set our result incremental variable to 1
			export resultInt=1

			echo -e "\n\nPosting ${jssitem[$loop]} to new JSS instance: $destjssaddress$jssinstance"
		
			case "${jssitem[$loop]}" in
				accounts)
					echo -e "\nPosting user accounts."

					totalParsedResourceXML_user=$( ls $xmlloc/${jssitem[$loop]}/parsed_xml/*user* | wc -l | sed -e 's/^[ \t]*//' )
					postInt_user=0	

					for xmlPost_user in $(ls -1 $xmlloc/${jssitem[$loop]}/parsed_xml/*user*)
					do
						let "postInt_user = $postInt_user + 1"
						echo -e "\nPosting $xmlPost_user ( $postInt_user out of $totalParsedResourceXML_user )"
						curl -k -H "Content-Type: application/xml" -X POST --data-binary @"$xmlPost_user" "$destjssaddress/JSSResource/accounts/userid/0" -u "$destjssapiuser:$destjssapipwd"
					done

					echo -e "\nPosting user group accounts."

					totalParsedResourceXML_group=$( ls $xmlloc/${jssitem[$loop]}/parsed_xml/*group* | wc -l | sed -e 's/^[ \t]*//' )
					postInt_group=0	

					for xmlPost_group in $(ls -1 $xmlloc/${jssitem[$loop]}/parsed_xml/*group*)
					do
						let "postInt_group = $postInt_group + 1"
						echo -e "\nPosting $xmlPost_group ( $postInt_group out of $totalParsedResourceXML_group )"
						curl -k -H "Content-Type: application/xml" -X POST --data-binary @"$xmlPost_group" "$destjssaddress/JSSResource/accounts/groupid/0" -u "$destjssapiuser:$destjssapipwd"
					done
				;;	
				
				computergroups)
					echo -e "\nPosting static computer groups."

					totalParsedResourceXML_staticGroups=$(ls $xmlloc/${jssitem[$loop]}/parsed_xml/static_group_parsed* | wc -l | sed -e 's/^[ \t]*//')
					postInt_static=0

					for parsedXML_static in $(ls -1 $xmlloc/${jssitem[$loop]}/parsed_xml/static_group_parsed*)
					do
						let "postInt_static = $postInt_static + 1"
						echo -e "\nPosting $parsedXML_static ( $postInt_static out of $totalParsedResourceXML_staticGroups )"
						curl -k -H "Content-Type: application/xml" -X POST --data-binary @"$parsedXML_static" "$destjssaddress/JSSResource/${jssitem[$loop]}/id/0" -u "$destjssapiuser:$destjssapipwd"
					done

					echo -e "\nPosting smart computer groups"

					totalParsedResourceXML_smartGroups=$(ls $xmlloc/${jssitem[$loop]}/parsed_xml/smart_group_parsed* | wc -l | sed -e 's/^[ \t]*//')
					postInt_smart=0	

					for parsedXML_smart in $(ls -1 $xmlloc/${jssitem[$loop]}/parsed_xml/smart_group_parsed*)
					do
						let "postInt_smart = $postInt_smart + 1"
						echo -e "\nPosting $parsedXML_smart ( $postInt_smart out of $totalParsedResourceXML_smartGroups )"
						curl -k -H "Content-Type: application/xml" -X POST --data-binary @"$parsedXML_smart" "$destjssaddress/JSSResource/${jssitem[$loop]}/id/0" -u "$destjssapiuser:$destjssapipwd"
					done
				;;
		
				*)
					totalParsedResourceXML=$(ls $xmlloc/${jssitem[$loop]}/parsed_xml | wc -l | sed -e 's/^[ \t]*//')
					postInt=0	

					for parsedXML in $(ls $xmlloc/${jssitem[$loop]}/parsed_xml)
					do
						let "postInt = $postInt + 1"
						echo -e "\nPosting $parsedXML ( $postInt out of $totalParsedResourceXML )"
						curl -k -H "Content-Type: application/xml" -X POST --data-binary @"$xmlloc/${jssitem[$loop]}/parsed_xml/$parsedXML" "$destjssaddress/JSSResource/${jssitem[$loop]}/id/0" -u "$destjssapiuser:$destjssapipwd"
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

MainMenu()
{
	# Set IFS to only use new lines as field separator.
	OIFS=$IFS
	IFS=$'\n'

	while [[ $choice != "q" ]]
	do
		echo -e "\nMain Menu"
		echo -e "=========\n"
		echo -e "1) Download config from original JSS"
		echo -e "2) Upload config to new JSS instance"

		echo -e "q) Quit!\n"

		read -p "Choose an option (1-2 / q) : " choice

		case "$choice" in
			1)
				echo -e "\n"
				read -p "Enter the originating JSS server address (https://www.example.com:8443) : " jssaddress
				read -p "Enter the originating JSS server api username : " jssapiuser
				read -p "Enter the originating JSS api user password : " -s jssapipwd
				export origjssaddress=$jssaddress
				export origjssapiuser=$jssapiuser
				export origjssapipwd=$jssapipwd

				grabexistingjssxml
			;;
			2)
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

				puttonewjss				
			;;
			q)
				echo -e "\nThank you for using JSS Config in a Box!"
			;;
			*)
				echo -e "\nIncorrect input. Please try again." 
			;;
		esac
	done

	# Setting IFS back to default 
	IFS=$OIFS
}

# Start menu screen here
clear
echo -e "\n----------------------------------------"
echo -e "\n          JSS Config in a Box"
echo -e "\n----------------------------------------"
echo -e "    Version $currentver - $currentverdate"
echo -e "----------------------------------------\n"
echo -e "** Very Important Info **"
echo -e "\n1. Passwords WILL NOT be migrated with standard accounts. You must put these in again manually."
echo -e "2. Both macOS and iOS devices will NOT be migrated at all."
echo -e "3. Smart Computer Groups will only contain logic information."
echo -e "4. Static Computer groups will only contain name and site membership. Devices must be added manually."
echo -e "5. Distribution Point failover settings will NOT be included."
echo -e "6. Distribution Point passwords for Casper R/O and Casper R/W accounts will NOT be included."
echo -e "7. LDAP Authentication passwords will NOT be included."
echo -e "8. Directory Binding account passwords will NOT be included."
echo -e "9. Individual computers that are excluded from restricted software items WILL NOT be included in migration."
echo -e "10. Policies that are not assigned to a category will NOT be migrated."
echo -e "11. Policies that have Self Service icons and individual computers as a scope or exclusion will have these items missing."
echo -e "12. Policies with LDAP Users and Groups limitations will have these stripped before migration."

# Call functions to make this work here
doesxmlfolderexist
MainMenu

# All done!
exit 0