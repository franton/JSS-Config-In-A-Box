# JSS-Config-In-A-Box

### Introduction

This allows you to clone a JSS via the API to a new JSS server.

### Attribution

Big thanks to Jeffrey Compton for the API work he did with this:
https://github.com/igeekjsc/JSSAPIScripts/blob/master/jssMigrationUtility.bash

I have merely restructured a lot of his code to suit my own needs.

### Getting started

1. Run the script.
2. Follow the prompts.
3. There is no step 3!

You will be asked for a location to store xml data from the JSS API.
If data already exists, then you'll be asked if you wish to archive it. Otherwise the folders will be created.

You have two choices. Download or Upload. Selecting either will prompt for server details and credentials.

Current limitation is it will only read from a non context JSS, but will upload to a multi context JSS.