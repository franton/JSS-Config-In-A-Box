#!/bin/bash

# Script to either save JSS config via api to XML or upload that XML to a new JSS

# Loosely based on the work by Jeffrey Compton at
# https://github.com/igeekjsc/JSSAPIScripts/blob/master/jssMigrationUtility.bash
# His hard work is acknowledged and gratefully used. (and abused).

# Author : richard@richard-purves.com
# v0.1 : 10-05-2017 - Initial Version
# v0.2 : 15-05-2017 - Download works. Misses out empty items. Upload still fails hard.
# v0.3 : 16-05-2017 - Upload code in test. Improvements to UI. Code simplification.
# v0.4 : 16-05-2017 - Skips empty JSS categories on download. Properly archives existing download. Choice of storage location for xml files.
# v0.5 : 17-05-2017 - Debugged condition that "for some reason" tried to delete my entire machine. Nearly succeeded too.
#					- Skips empty categories now for a significant speed improvement. Upload mostly works at this point.
# v0.6 : 17-05-2017 - Check for existing xml. Creates folders if missing, archives existing files if required. Upload fails on a few things.
# v0.7 : 17-05-2017 - Edging closer towards release candidate status. API code seems happier. App layout work required next.
# v0.8 : 18-05-2017 - Mostly working. Fails on duplicate account name(s) (expected). Will upload App Store apps, but error if VPP isn't working (expected). Fails on policies that create accounts (huh?).
# v1.0 : 24-05-2017 - Upload/Download working. Archival of old data wasn't working.
# v1.1 : 24-05-2017 - Added multi context support for both originating and destination JSS' (blame MacMule .. it's always his fault!)
# v1.5 : 21-07-2017 - Fixed versioning dates. Added a wipe section before upload to clear any existing config. Brute force but works.
# v1.6 : 31-07-2017 - Found the order to read things out is different to writing them back. So 2nd array goes in to fix.
# v1.7 : 23-08-2017 - Explicitly specifying xml to the JSS seems to help a little with certain edge cases.
# v1.8 : 30-08-2017 - Enforces xml use with the JSS API. Different java installs default to JSON.
# v1.9 : 05-09-2017 - Thanks to Graham Pugh who found issues with SMTP server setting. Now fixed along with gsxconnection.
# v2.0 : 02-11-2017 - Moved the xml archiving code around so it only runs at download.
# v2.1 : 03-11-2017 - Thanks to Sam Fortuna at Jamf who pointed out why password uploads were not working. Now they upload with temp password set below.

# Set up variables here
export resultInt=1
export currentver="2.1"
export currentverdate="3rd November 2017"
export temppassword="changemenow"

# These are the categories we're going to save or wipe
declare -a readwipe
readwipe[0]="sites"							# Backend configuration
readwipe[1]="categories"
readwipe[2]="ldapservers"
readwipe[3]="accounts"
readwipe[4]="buildings"
readwipe[5]="departments"
readwipe[6]="directorybindings"
readwipe[7]="removablemacaddresses"
readwipe[8]="netbootservers"
readwipe[9]="distributionpoints"
readwipe[10]="softwareupdateservers"
readwipe[11]="networksegments"
readwipe[12]="healthcarelistener"
readwipe[13]="ibeacons"
readwipe[14]="infrastructuremanager"
readwipe[15]="peripherals"
readwipe[16]="peripheraltypes"
readwipe[17]="smtpserver"
readwipe[18]="vppaccounts"
readwipe[19]="vppassignments"
readwipe[20]="vppinvitations"
readwipe[21]="webhooks"
readwipe[22]="diskencryptionconfigurations"
readwipe[23]="ebooks"
readwipe[24]="computergroups" 				# Computer configuration
readwipe[25]="dockitems"
readwipe[26]="printers"
readwipe[27]="licensedsoftware"
readwipe[28]="scripts"
readwipe[29]="computerextensionattributes"
readwipe[30]="restrictedsoftware"
readwipe[31]="osxconfigurationprofiles"
readwipe[32]="macapplications"
readwipe[33]="managedpreferenceprofiles"
readwipe[34]="packages"
readwipe[35]="policies"
readwipe[36]="advancedcomputersearches"
readwipe[37]="patches"
readwipe[38]="mobiledevicegroups"			# Mobile configuration
readwipe[39]="mobiledeviceapplications"
readwipe[40]="mobiledeviceconfigurationprofiles"
readwipe[41]="mobiledeviceenrollmentprofiles"
readwipe[42]="mobiledeviceextensionattributes"
readwipe[43]="mobiledeviceprovisioningprofiles"
readwipe[44]="classes"
readwipe[45]="advancedmobiledevicesearches"
readwipe[46]="userextensionattributes"		# User configuration
readwipe[47]="usergroups"
readwipe[48]="users"
readwipe[49]="advancedusersearches"
readwipe[50]="gsxconnection"

# These are the categories we're going to upload. Ordering is different from read/wipe.
declare -a writebk
writebk[0]="sites"							# Backend configuration
writebk[1]="categories"
writebk[2]="ldapservers"
writebk[3]="accounts"
writebk[4]="buildings"
writebk[5]="departments"
writebk[6]="directorybindings"
writebk[7]="removablemacaddresses"
writebk[8]="netbootservers"
writebk[9]="distributionpoints"
writebk[10]="softwareupdateservers"
writebk[11]="networksegments"
writebk[12]="healthcarelistener"
writebk[13]="ibeacons"
writebk[14]="infrastructuremanager"
writebk[15]="peripherals"
writebk[16]="peripheraltypes"
writebk[17]="smtpserver"
writebk[18]="vppaccounts"
writebk[19]="vppassignments"
writebk[20]="vppinvitations"
writebk[21]="webhooks"
writebk[22]="diskencryptionconfigurations"
writebk[23]="ebooks"
writebk[24]="computerextensionattributes" 		# Computer configuration
writebk[25]="dockitems"
writebk[26]="printers"
writebk[27]="licensedsoftware"
writebk[28]="scripts"
writebk[29]="computergroups"
writebk[30]="restrictedsoftware"
writebk[31]="osxconfigurationprofiles"
writebk[32]="macapplications"
writebk[33]="managedpreferenceprofiles"
writebk[34]="packages"
writebk[35]="policies"
writebk[36]="advancedcomputersearches"
writebk[37]="patches"
writebk[38]="mobiledeviceextensionattributes"		# Mobile configuration
writebk[39]="mobiledeviceapplications"
writebk[40]="mobiledeviceconfigurationprofiles"
writebk[41]="mobiledeviceenrollmentprofiles"
writebk[42]="mobiledevicegroups"
writebk[43]="mobiledeviceprovisioningprofiles"
writebk[44]="classes"
writebk[45]="advancedmobiledevicesearches"
writebk[46]="userextensionattributes"				# User configuration
writebk[47]="usergroups"
writebk[48]="users"
writebk[49]="advancedusersearches"
writebk[50]="gsxconnection"

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
	for (( loop=0; loop<${#readwipe[@]}; loop++ ))
	do
		if [ "$archive" = "YES" ];
		then
			if [ `ls -1 "$xmlloc"/"${readwipe[$loop]}"/* 2>/dev/null | wc -l` -gt 0 ];
			then
				echo "Archiving category: "${readwipe[$loop]}
				ditto -ck "$xmlloc"/"${readwipe[$loop]}" "$xmlloc"/archives/"${readwipe[$loop]}"-$( date +%Y%m%d%H%M%S ).zip
				rm -rf "$xmlloc/${readwipe[$loop]}"
			fi
		fi

	# Check and create the JSS xml resource folders if missing.
		if [ ! -f "$xmlloc/${readwipe[$loop]}" ];
		then
			mkdir -p "$xmlloc/${readwipe[$loop]}"
			mkdir -p "$xmlloc/${readwipe[$loop]}/id_list"
			mkdir -p "$xmlloc/${readwipe[$loop]}/fetched_xml"
			mkdir -p "$xmlloc/${readwipe[$loop]}/parsed_xml"
		fi
	done
}

grabexistingjssxml()
{
	# Setting IFS Env to only use new lines as field seperator 
	OIFS=$IFS
	IFS=$'\n'

	# Loop around the array of JSS categories we set up earlier.
	for (( loop=0; loop<${#readwipe[@]}; loop++ ))
	do	
		# Set our result incremental variable to 1
		export resultInt=1

		# Work out where things are going to be stored on this loop
		export formattedList=$xmlloc/${readwipe[$loop]}/id_list/formattedList.xml
		export plainList=$xmlloc/${readwipe[$loop]}/id_list/plainList
		export plainListAccountsUsers=$xmlloc/${readwipe[$loop]}/id_list/plainListAccountsUsers
		export plainListAccountsGroups=$xmlloc/${readwipe[$loop]}/id_list/plainListAccountsGroups
		export fetchedResult=$xmlloc/${readwipe[$loop]}/fetched_xml/result"$resultInt".xml
		export fetchedResultAccountsUsers=$xmlloc/${readwipe[$loop]}/fetched_xml/userResult"$resultInt".xml
		export fetchedResultAccountsGroups=$xmlloc/${readwipe[$loop]}/fetched_xml/groupResult"$resultInt".xml	
	
		# Grab all existing ID's for the current category we're processing
		echo -e "\n\nCreating ID list for ${readwipe[$loop]} on template JSS \n"
		curl -s -k $origjssaddress$jssinstance/JSSResource/${readwipe[$loop]} -H "Accept: application/xml" --user "$origjssapiuser:$origjssapipwd" | xmllint --format - > $formattedList

		if [ ${readwipe[$loop]} = "accounts" ];
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
		fi
		
		if [ ${readwipe[$loop]} = "activationcode" ] || [ ${readwipe[$loop]} = "gsxconnection" ] || [ ${readwipe[$loop]} = "smtpserver" ];
		then
			echo -e "Single entry item. Generic plain list ${readwipe[$loop]} generated. \n"
			echo "1" > $plainList
		else
			if [ `cat "$formattedList" | grep "<size>0" | wc -l | awk '{ print $1 }'` = "0" ];
			then
				echo -e "\n\nCreating a plain list of ${readwipe[$loop]} ID's \n"
				cat $formattedList | awk -F'<id>|</id>' '/<id>/ {print $2}' > $plainList
			else
				rm $formattedList
			fi
		fi

		# Work out how many ID's are present IF formattedlist is present. Grab and download each one for the specific search we're doing. Special code for accounts because the API is annoyingly different from the rest.
		if [ `ls -1 "$xmlloc/${readwipe[$loop]}/id_list"/* 2>/dev/null | wc -l` -gt 0 ];
		then
			case "${readwipe[$loop]}" in
				accounts)
					totalFetchedIDsUsers=$( cat "$plainListAccountsUsers" | wc -l | sed -e 's/^[ \t]*//' )
					for userID in $( cat $plainListAccountsUsers )
					do
						echo "Downloading User ID number $userID ( $resultInt out of $totalFetchedIDsUsers )"
						fetchedResultAccountsUsers=$( curl --silent -k --user "$origjssapiuser:$origjssapipwd" -H "Content-Type: application/xml" -X GET "$origjssaddress/JSSResource/${readwipe[$loop]}/userid/$userID" | xmllint --format - )
						itemID=$( echo "$fetchedResultAccountsUsers" | grep "<id>" | awk -F '<id>|</id>' '{ print $2; exit; }')
						itemName=$( echo "$fetchedResultAccountsUsers" | grep "<name>" | awk -F '<name>|</name>' '{ print $2; exit; }')
						cleanedName=$( echo "$itemName" | sed 's/[:\/\\]//g' )
						fileName="$cleanedName [ID $itemID]"
						echo "$fetchedResultAccountsUsers" > $xmlloc/${readwipe[$loop]}/fetched_xml/user_"$resultInt.xml"
					
						let "resultInt = $resultInt + 1"
					done

					resultInt=1

					totalFetchedIDsGroups=$( cat "$plainListAccountsGroups" | wc -l | sed -e 's/^[ \t]*//' )
					for groupID in $( cat $plainListAccountsGroups )
					do
						echo "Downloading Group ID number $groupID ( $resultInt out of $totalFetchedIDsGroups )"
						fetchedResultAccountsGroups=$( curl --silent -k --user "$origjssapiuser:$origjssapipwd" -H "Content-Type: application/xml" -X GET "$origjssaddress/JSSResource/${readwipe[$loop]}/groupid/$groupID" | xmllint --format - )
						itemID=$( echo "$fetchedResultAccountsGroups" | grep "<id>" | awk -F '<id>|</id>' '{ print $2; exit; }')
						itemName=$( echo "$fetchedResultAccountsGroups" | grep "<name>" | awk -F '<name>|</name>' '{ print $2; exit; }')
						cleanedName=$( echo "$itemName" | sed 's/[:\/\\]//g' )
						fileName="$cleanedName [ID $itemID]"
						echo "$fetchedResultAccountsGroups" > $xmlloc/${readwipe[$loop]}/fetched_xml/group_"$resultInt.xml"
					
						let "resultInt = $resultInt + 1"
					done			
				;;

				activationcode|gsxconnection|smtpserver)
					echo "Downloading single entry"
					curl -s -k --user "$origjssapiuser:$origjssapipwd" -H "Content-Type: application/xml" -X GET "$origjssaddress/JSSResource/${readwipe[$loop]}" | xmllint --format - > $fetchedResult
				;;

				*)
					totalFetchedIDs=`cat "$plainList" | wc -l | sed -e 's/^[ \t]*//'`

					for apiID in $(cat $plainList)
					do
						echo "Downloading ID number $apiID ( $resultInt out of $totalFetchedIDs )"
						curl -s -k --user "$origjssapiuser:$origjssapipwd" -H "Content-Type: application/xml" -X GET "$origjssaddress/JSSResource/${readwipe[$loop]}/id/$apiID" | xmllint --format - > $fetchedResult
						resultInt=$(($resultInt + 1))
						fetchedResult=$xmlloc/${readwipe[$loop]}/fetched_xml/result"$resultInt".xml
					done	
				;;
			esac
			
			# Depending which category we're dealing with, parse the grabbed files into something we can upload later.
			case "${readwipe[$loop]}" in	
				computergroups)
					echo -e "\nParsing JSS computer groups"

					for resourceXML in $(ls $xmlloc/${readwipe[$loop]}/fetched_xml)
					do
						echo "Parsing computer group: $resourceXML"

						if [[ `cat $xmlloc/${readwipe[$loop]}/fetched_xml/$resourceXML | grep "<is_smart>false</is_smart>"` ]]
						then
							echo "$resourceXML is a static computer group"
							cat $xmlloc/${readwipe[$loop]}/fetched_xml/$resourceXML | grep -v "<id>" | sed '/<computers>/,/<\/computers/d' > $xmlloc/${readwipe[$loop]}/parsed_xml/static_group_parsed_"$resourceXML"
						else
							echo "$resourceXML is a smart computer group..."
							cat $xmlloc/${readwipe[$loop]}/fetched_xml/$resourceXML | grep -v "<id>" | sed '/<computers>/,/<\/computers/d' > $xmlloc/${readwipe[$loop]}/parsed_xml/smart_group_parsed_"$resourceXML"
						fi					
					done
				;;

				policies|restrictedsoftware)
					echo -e "\nParsing ${readwipe[$loop]}"

					for resourceXML in $(ls $xmlloc/${readwipe[$loop]}/fetched_xml)
					do
						echo "Parsing policy: $resourceXML"
			
						if [[ `cat $xmlloc/${readwipe[$loop]}/fetched_xml/$resourceXML | grep "<name>No category assigned</name>"` ]]
						then
							echo "Policy $resourceXML is not assigned to a category. Ignoring."
						else
							echo "Processing policy file $resourceXML ."
							cat $xmlloc/${readwipe[$loop]}/fetched_xml/$resourceXML | grep -v "<id>" | sed '/<computers>/,/<\/computers>/d' | sed '/<self_service_icon>/,/<\/self_service_icon>/d' | sed '/<limit_to_users>/,/<\/limit_to_users>/d' | sed '/<users>/,/<\/users>/d' | sed '/<user_groups>/,/<\/user_groups>/d' | sed 's/^.*<password_sha256.*/<password>'"${temppassword}"'<\/password>/' | sed 's/^.*<of_password_sha256.*/<of_password>'"${temppassword}"'<\/of_password>/' > $xmlloc/${readwipe[$loop]}/parsed_xml/parsed_"$resourceXML"
						fi
					done
				;;

				*)
					echo -e "\nNo special parsing needed for: ${readwipe[$loop]}. Removing references to ID's\n"

					for resourceXML in $(ls $xmlloc/${readwipe[$loop]}/fetched_xml)
					do
						echo "Parsing $resourceXML"
						cat $xmlloc/${readwipe[$loop]}/fetched_xml/$resourceXML | grep -v "<id>" | sed 's/^.*<password_sha256.*/<password>'"${temppassword}"'<\/password>/' > $xmlloc/${readwipe[$loop]}/parsed_xml/parsed_"$resourceXML"
					done
				;;
			esac
		else
			echo -e "\nResource ${readwipe[$loop]} empty. Skipping."
		fi
	done
	
	# Setting IFS back to default 
	IFS=$OIFS
}

wipejss()
{
	# Setting IFS Env to only use new lines as field seperator 
	OIFS=$IFS
	IFS=$'\n'
	
	# THIS IS YOUR LAST CHANCE TO PUSH THE CANCELLATION BUTTON

	echo -e "\nThis action will erase the destination JSS before upload."
	echo "Are you utterly sure you want to do this?"
	read -p "(Default is NO. Type YES to go ahead) : " arewesure

	# Check for the skip
	if [[ $arewesure != "YES" ]];
	then
		echo "Ok, quitting."
		exit 0
	fi

	# OK DO IT

	for (( loop=0; loop<${#readwipe[@]}; loop++ ))
	do
		if [ ${readwipe[$loop]} = "accounts" ];
		then
			echo -e "\nSkipping ${readwipe[$loop]} category. Or we can't get back in!"
		else
			# Set our result incremental variable to 1
			export resultInt=1

			# Grab all existing ID's for the current category we're processing
			echo -e "\n\nProcessing ID list for ${readwipe[$loop]}\n"
			curl -s -k --user "$jssapiuser:$jssapipwd" -H "Accept: application/xml" $jssaddress$jssinstance/JSSResource/${readwipe[$loop]} | xmllint --format - > /tmp/unprocessedid

			# Check if any ids have been captured. Skip if none present.
			check=$( echo /tmp/unprocessedid | grep "<size>0</size>" | wc -l | awk '{ print $1 }' )

			if [ "$check" = "0" ];
			then
				# What are we deleting?
				echo -e "\nDeleting ${readwipe[$loop]}"
	
				# Process all the item id numbers
				cat /tmp/unprocessedid | awk -F'<id>|</id>' '/<id>/ {print $2}' > /tmp/processedid

				# Delete all the item id numbers
				totalFetchedIDs=$( cat /tmp/processedid | wc -l | sed -e 's/^[ \t]*//' )

				for apiID in $(cat /tmp/processedid)
				do
					echo "Deleting ID number $apiID ( $resultInt out of $totalFetchedIDs )"
					curl -s -k --user "$jssapiuser:$jssapipwd" -H "Content-Type: application/xml" -X DELETE "$jssaddress$jssinstance/JSSResource/${readwipe[$loop]}/id/$apiID"
					resultInt=$(($resultInt + 1))
				done	
			else
				echo -e "\nCategory ${readwipe[$loop]} is empty. Skipping."
			fi
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

	for (( loop=0; loop<${#writebk[@]}; loop++ ))
	do
		if [ `ls -1 "$xmlloc"/"${writebk[$loop]}"/parsed_xml/* 2>/dev/null | wc -l` -gt 0 ];
		then
			# Set our result incremental variable to 1
			export resultInt=1

			echo -e "\n\nPosting ${writebk[$loop]} to new JSS instance: $destjssaddress$jssinstance"
		
			case "${writebk[$loop]}" in
				accounts)
					echo -e "\nPosting user accounts."

					totalParsedResourceXML_user=$( ls $xmlloc/${writebk[$loop]}/parsed_xml/*user* | wc -l | sed -e 's/^[ \t]*//' )
					postInt_user=0	

					for xmlPost_user in $(ls -1 $xmlloc/${writebk[$loop]}/parsed_xml/*user*)
					do
						let "postInt_user = $postInt_user + 1"
						echo -e "\nPosting $xmlPost_user ( $postInt_user out of $totalParsedResourceXML_user )"
						curl -k -H "Content-Type: application/xml" -X POST --data-binary @"$xmlPost_user" "$destjssaddress$jssinstance/JSSResource/accounts/userid/0" -u "$destjssapiuser:$destjssapipwd"
					done

					echo -e "\nPosting user group accounts."

					totalParsedResourceXML_group=$( ls $xmlloc/${writebk[$loop]}/parsed_xml/*group* | wc -l | sed -e 's/^[ \t]*//' )
					postInt_group=0	

					for xmlPost_group in $(ls -1 $xmlloc/${writebk[$loop]}/parsed_xml/*group*)
					do
						let "postInt_group = $postInt_group + 1"
						echo -e "\nPosting $xmlPost_group ( $postInt_group out of $totalParsedResourceXML_group )"
						curl -k -H "Content-Type: application/xml" -X POST --data-binary @"$xmlPost_group" "$destjssaddress$jssinstance/JSSResource/accounts/groupid/0" -u "$destjssapiuser:$destjssapipwd"
					done
				;;	
				
				computergroups)
					echo -e "\nPosting static computer groups."

					totalParsedResourceXML_staticGroups=$(ls $xmlloc/${writebk[$loop]}/parsed_xml/static_group_parsed* | wc -l | sed -e 's/^[ \t]*//')
					postInt_static=0

					for parsedXML_static in $(ls -1 $xmlloc/${writebk[$loop]}/parsed_xml/static_group_parsed*)
					do
						let "postInt_static = $postInt_static + 1"
						echo -e "\nPosting $parsedXML_static ( $postInt_static out of $totalParsedResourceXML_staticGroups )"
						curl -k -H "Content-Type: application/xml" -X POST --data-binary @"$parsedXML_static" "$destjssaddress$jssinstance/JSSResource/${writebk[$loop]}/id/0" -u "$destjssapiuser:$destjssapipwd"
					done

					echo -e "\nPosting smart computer groups"

					totalParsedResourceXML_smartGroups=$(ls $xmlloc/${writebk[$loop]}/parsed_xml/smart_group_parsed* | wc -l | sed -e 's/^[ \t]*//')
					postInt_smart=0	

					for parsedXML_smart in $(ls -1 $xmlloc/${writebk[$loop]}/parsed_xml/smart_group_parsed*)
					do
						let "postInt_smart = $postInt_smart + 1"
						echo -e "\nPosting $parsedXML_smart ( $postInt_smart out of $totalParsedResourceXML_smartGroups )"
						curl -k -H "Content-Type: application/xml" -X POST --data-binary @"$parsedXML_smart" "$destjssaddress$jssinstance/JSSResource/${writebk[$loop]}/id/0" -u "$destjssapiuser:$destjssapipwd"
					done
				;;
				
				activationcode|gsxconnection|smtpserver)
					totalParsedResourceXML=$(ls $xmlloc/${writebk[$loop]}/parsed_xml | wc -l | sed -e 's/^[ \t]*//')
					postInt=0	

					for parsedXML in $(ls $xmlloc/${writebk[$loop]}/parsed_xml)
					do
						let "postInt = $postInt + 1"
						echo -e "\nPosting $parsedXML ( $postInt out of $totalParsedResourceXML )"
						curl -k -H "Content-Type: application/xml" -X PUT --data-binary @"$xmlloc/${writebk[$loop]}/parsed_xml/$parsedXML" "$destjssaddress$jssinstance/JSSResource/${writebk[$loop]}/" -u "$destjssapiuser:$destjssapipwd"
					done
				;;
		
				*)
					totalParsedResourceXML=$(ls $xmlloc/${writebk[$loop]}/parsed_xml | wc -l | sed -e 's/^[ \t]*//')
					postInt=0	

					for parsedXML in $(ls $xmlloc/${writebk[$loop]}/parsed_xml)
					do
						let "postInt = $postInt + 1"
						echo -e "\nPosting $parsedXML ( $postInt out of $totalParsedResourceXML )"
						curl -k -H "Content-Type: application/xml" -X POST --data-binary @"$xmlloc/${writebk[$loop]}/parsed_xml/$parsedXML" "$destjssaddress$jssinstance/JSSResource/${writebk[$loop]}/id/0" -u "$destjssapiuser:$destjssapipwd"
					done
				;;
			esac		
		else
			echo -e "\nResource ${writebk[$loop]} empty. Skipping."
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
				doesxmlfolderexist
				
				echo -e "\n"
				read -p "Enter the originating JSS server address (https://www.example.com:8443) : " jssaddress
				read -p "Enter the originating JSS server api username : " jssapiuser
				read -p "Enter the originating JSS api user password : " -s jssapipwd
				export origjssaddress=$jssaddress
				export origjssapiuser=$jssapiuser
				export origjssapipwd=$jssapipwd

				# Ask which instance we need to process, check if it exists and go from there
				echo -e "\n"
				echo "Enter the destination JSS instance name to download"
				read -p "(Or enter for a non-context JSS) : " jssinstance

				# Check for the skip
				if [[ $jssinstance != "" ]];
				then
					jssinstance="/$instance/"
				fi

				grabexistingjssxml
			;;
			2)
				echo -e "\nPlease enter the path to read data"
				read -p "(Or enter to use $HOME/Desktop/JSS_Config) : " xmlloc

				if [[ $path = "" ]];
				then
					export xmlloc="$HOME/Desktop/JSS_Config"
				fi

				if [[ ! -d "$xmlloc" ]];
				then
					echo -e "\nERROR: Specified directory does not exist. Exiting."
					continue
				fi

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

				wipejss
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
echo -e "\n1. Passwords WILL NOT be migrated with accounts, policies or EFI. You must put these in again manually."
echo -e "2. ALL passwords uploaded are currently set to: $temppassword"
echo -e "3. Both macOS and iOS devices will NOT be migrated at all."
echo -e "4. Smart Computer Groups will only contain logic information."
echo -e "5. Static Computer groups will only contain name and site membership. Devices must be added manually."
echo -e "6. Distribution Point failover settings will NOT be included."
echo -e "7. Distribution Point passwords for Casper R/O and Casper R/W accounts will NOT be included."
echo -e "8. LDAP Authentication passwords will NOT be included."
echo -e "9. Directory Binding account passwords will NOT be included."
echo -e "10. Individual computers that are excluded from restricted software items WILL NOT be included in migration."
echo -e "11. Policies that are not assigned to a category will NOT be migrated."
echo -e "12. Policies that have Self Service icons and individual computers as a scope or exclusion will have these items missing."
echo -e "13. Policies with LDAP Users and Groups limitations will have these stripped before migration."

# Call functions to make this work here
MainMenu

# All done!
exit 0