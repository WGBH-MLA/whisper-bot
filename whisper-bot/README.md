# Workflow to install Dockerized whisper-ai for use with Amazon S3

#### Created by Kevin Carter, last modified on Jun 07, 2023

Stop here if your "About This Mac" reports anything like "Chip: Apple M1" or "Chip: Apple M2" because it will run the whisper in Docker too slowly. Alternative instructions are being developed.
Do this on your Intel-powered Mac; it runs in the background to help "crowd-source" the creation of text transcripts from audio recordings; set it and forget it or pause it when you need downtime.  
Open application "Terminal" and a new window; if its last line of text ends with % then type and enter /bin/bash; that should be done in any new window/tabs used below. Recommended: if you're not already a regular user of Terminal with a preference for Apple's new default zsh, then

open the application's preferences (key combo [ cmd ] [ , ] or point/click/select application menu "Terminal" then menu item "Preferences")

and set the "General" preference to open new windows with /bin/bash

illustrated

Gain privileges to act as local administrator; you will need them to install necessary software dependencies. Or, ask IT to perform the following steps #'s 4-7

Install the UNIX utility git : https://git-scm.com/download/mac
Install the UNIX utility aws : https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2-mac.html
Install the UNIX utility jq : https://stedolan.github.io/jq/download/
Download and install Docker Community Edition (stable) for Mac
https://www.docker.com
https://store.docker.com/editions/community/docker-ce-desktop-mac
Launch Docker, configure its preferences and restart Docker after setting these:
Preferences General:
Start Docker when you log in = true
Automatically check for updates = false
Include VM in Time Machine backups = false
Securely store docker logins in macOS keychain = true
Send usage statistics = true
Preferences Advanced:
CPUs: = 2 (assumes 2 multicores available on system)
Memory: = 6.5 GB (assuming 16GB available on system)
Launch the application "Terminal" and open a new window. Copy/paste text from below into the terminal window and then press the enter key to verify that your UNIX utilities (above) can be used.

```bash
which aws docker jq  | cat -n # comment: result should be three numbered lines output
```

Stop here if the previous step did not output three numbered lines. Reach out for help: send email with the output result
If you already have used the command line tools, skip to item c of this step. Otherwise, install aws configuration data now.
Copy/paste text of the following section and press the enter key to ensure that directory $HOME/.aws exists and has adequate permissions.

```bash
mkdir -p $HOME/.aws $HOME/.cache/whisper && chmod 755 $HOME/.aws $HOME/.cache/whisper
```

Copy/paste text of the following section and press the enter key to ensure that files $HOME/.aws/config and $HOME/.aws/credentials exist with restricted permissions.

```bash
touch $HOME/.aws/config $HOME/.aws/credentials && chmod 600 $HOME/.aws/config $HOME/.aws/credentials
```

If you have access to the wgbh-mla account for AWS, log into the aws web console (in your browser), navigate to IAM service:Users:yourself:Security Credentials and then click the button [ Create access key ] .  
use Account ID (alias) 'wgbh-mla'
use your IAM user name and password
be sure to copy and keep ready the resulting values for the next step! Recommended: download the CSV file for easy reference.
Have your credentials and secret access key values ready? Copy/paste text of the following section and then press the enter key to create a aws profile named 'wgbh-mla'

```bash
# comments: Use your values for aws_access_key_id and aws_secret_access_key
# specify 'us-east-1' for region
# press the enter key to simply accept default value for output format
aws configure --profile wgbh-mla
```

In an open window of the application "Terminal," copy/paste the following and press the enter key to verify that you can access a necessary S3 resource.

```bash
aws s3api list-objects --profile wgbh-mla --bucket asr-listing --query 'Contents[0]'  # comment: result should begin with '{"Key" :  '
```

If the previous step results in anything like "Error" or "Denied", reach out for help. Send email with aws info
In an open window of the application "Terminal," do the following steps to create local, custom docker "images" and executable scripts for our use.

```bash
# copy/paste the following section into the terminal window and then press the enter key to download the basic whisper docker image ;

docker pull ghcr.io/wgbh-mla/whisper-bot:v0.2.0  # comment:  this download and install will take a while
# copy/paste the following section into the terminal window and then press the enter key to create directories and empty files to be used ;

mkdir -p "$HOME"/.docker/mnt/s3 && cd "$HOME"/.docker/mnt/s3 && touch whispermedia.sh vtt_2_fixit_json.sh && chmod +x whispermedia.sh vtt_2_fixit_json.sh ;

# copy/paste text of the following section into the terminal window and then press the enter key to check for success of the previous operation ;

if [ "$(docker images ghcr.io/wgbh-mla/whisper-bot:v0.2.0 | wc -l | awk '{print $1}')" -ne 2 ] ; then echo 'HELP!  docker failed to download the image' ; else echo 'SUCCESS!' ; fi ;
```

Stop here if the previous step did not report "SUCCESS!" Reach out for help: send email
Using an open window of the application "Terminal," do the following steps:

```bash
#  copy/paste text of the following section into the terminal window and then press the enter key to put text into the file 'whispermedia.sh' ;

cat << 'EOF' > "$HOME"/.docker/mnt/s3/whispermedia.sh
#!/bin/bash -l

# user launchagent runs this every 15 mins (adjust in plist file)
# it does sanity checks and exits noisily if the user lacks libraries
#  it exits quietly if it detects that a previous iteration of the script is still running
# this script runs on the mac and uses a docker container to perform audio speech recognition (ASR)



helperMail="kevin_carter@wgbh.org";
helperURL="https://wiki.wgbh.org/x/6hTzC" ;

ASR_IMAGE='ghcr.io/wgbh-mla/whisper-bot:v0.2.0' ; # formatted as "repository/image:tag"
whisper_model='base' ;

startupTimeout=45 ; #positive integer of seconds max for docker to launch
mediadir=$(cd "$(dirname "$0")" && pwd -P) ;
myname=$(basename "$0") ;
containerNAMEfile="$mediadir"/containername.txt ;
prefixfile="$mediadir"/s3keyprefix.txt ;

defaultS3prefix='cpb-aacip' ;
suspendS3prefix='_SUSPEND_' ; # CHANGE CONTENTS OF FILE TO SUSPEND FUTURE PROCESSING

s3profile='wgbh-mla' ;
s3resourcebucket='asr-rsrc';
s3listingbucket='asr-listing';
s3mediabucket='asr-media';
s3outputbucket='asr-dockerwhisper-output' ;
s3xfererrfile="$mediadir"/s3xfer.err ;
starttime="$(date -j -f "%a %b %d %T %Z %Y" "`date`" "+%s")" ;

callForHelp() {
        whatHelp=$1
        open "$helperURL"
        open "mailto:$helperMail?subject=help&su=help&cc=$USER@wgbh.org&body=$whatHelp"
}
#

# initialize local resource files
touch "$containerNAMEfile" ;
touch "$prefixfile" ;
if [ ! -s "$prefixfile" ];
then printf %s "$defaultS3prefix" > "$prefixfile" ;
elif [ "$(head -1 "$prefixfile" )" == "$suspendS3prefix" ] ;
then exit ; # THIS IS HOW TO DISABLE WITHOUT UNINSTALLING
fi

thisS3prefix=$(cat "$prefixfile" ) ; # NOTES BELOW
#NOTE:  this permits use of foobar/ on S3 to permit coordinated prioritization of subsets
# ALSO:  see formulation of "$guid" for subdirectory naming

# BEGIN SANITY CHECKS

# sanity check to prevent multiple instances of this script running when another is just waiting for media to arrive
if [ "$(lsof "$mediadir"/"$myname" | grep -c '^bash' | awk '{print $1}')" -gt 1 ];
then
    exit ;
fi

# sanity checks for system-level binaries
for utility in 'aws' 'docker' 'jq' ;
do
    if [ -z "$(which "$utility")" ] ;
    then
        userChoice="$(osascript -e 'display dialog "Application \"'"$utility"'\" is needed but not found" with title "ERROR" with icon 0 buttons {"Help"} default button 1 giving up after 10' -e 'button returned of result')" ;
        if [ "$userChoice" == 'Help' ] ;
        then
            callForHelp "I%20need%20%22$utility%22%20to%20be%20installed" ;
        fi ;
        exit ;
    fi ;
done

# sanity checks for aws stuff
for bucket in "$s3mediabucket" "$s3listingbucket" "$s3outputbucket";
do
    if [ ! -z "$(aws s3api head-bucket --profile $s3profile --bucket "$bucket" 2>&1)" ]
    then
        userChoice="$(osascript -e 'display dialog "Application \"aws\" cannot access a needed bucket: \"'$bucket'\"" with title "ERROR" with icon 0 buttons {"Help"} default button 1 giving up after 10' -e 'button returned of result')"
        if [ "$userChoice" == 'Help' ]
        then
            callForHelp "I%20need%20aws-cli%20access%20to%20bucket%20$bucket"
        fi
    exit
    fi
done

# sanity checks for docker stuff
dockerinfo=$(docker info 2>&1  ) ;
memunits=$(echo "$dockerinfo" | grep 'Total Memory:' | sed 's#^.*[0-9]##g'  | cut -c1 | tr '[[:lower:]]' '[[:upper:]]') ;
if [ "$(echo "$memunits" | tr -dC '[GTP]')" == "$memunits" ] ;
then
    meminteger=$(echo "$dockerinfo" | grep 'Total Memory:' | tr -dC '[[0-9].]' | sed 's#\..*##g') ;
else
    meminteger=0 ; # $memunits is not Gigabytes nor Terabytes nor Petabytes
fi
if [ "$meminteger" != 0 -a "$meminteger" -lt 6 -a "$memunits" != "G" ] ;
then
    userChoice="$(osascript -e 'display dialog "Application \"docker\" preferences are misconfigured.  Allocate at least 6GB of memory for Kaldi ASR processing." with title "ERROR" with icon 0 buttons {"Help"} default button 1 giving up after 10' -e  'button returned of result')"
    if [ "$userChoice" == 'Help' ]
    then
        callForHelp "Docker%20preferences%20for%20memory%20are%20misconfigured."
    fi ;
    exit ;
fi

if [ ! -z "$(echo $dockerinfo | grep 'ERROR\|Is the docker daemon running?')" ] ;
then
    open -a Docker >/dev/null 2>&1 &
    while [ -z "$(docker info 2>/dev/null)" ]
    do
        sleep 5
        nowtime="$(date -j -f "%a %b %d %T %Z %Y" "`date`" "+%s")"
        if [ "$(expr $nowtime - $starttime)" -gt "$startupTimeout" ]
        then
            userChoice="$(osascript -e 'display dialog "Application \"docker\" took too long to launch" with title "ERROR" with icon 0 buttons {"Help"} default button 1 giving up after 10' -e  'button returned of result')"
            if [ "$userChoice" == 'Help' ]
            then
                callForHelp "Docker%20took%20too%20long%20to%20launch."
            fi ;
        exit ;
        fi ;
    done
fi

for imagename in "$ASR_IMAGE"  ; #"$AES_IMAGE" ;
do
    if [ "$( docker images "$ASR_IMAGE" | awk '{print $1":"$2}' | grep "$ASR_IMAGE" )" != "$imagename" ]
    then
        userChoice="$(osascript -e 'display dialog "Image \"'"$imagename"'\" for application \"docker\" is needed but missing" with title "ERROR" with icon 0 buttons {"Help"} default button 1 giving up after 10' -e  'button returned of result')"
        if [ "$userChoice" == 'Help' ] ;
        then
            callForHelp "docker%20image%20$imagename%20not%20installed" ;
        fi ;
        exit ;
    fi ;
done

# exit now if docker is still running a file
#
lastcontainerNAME=$(cat "$containerNAMEfile") ;
if [ ! -z "$lastcontainerNAME" ] ;
then
    if [ ! -z "$(docker ps --no-trunc -f name="$lastcontainerNAME" | grep "$lastcontainerNAME" )" ] ;
    then
        exit ;
    else
        printf %s > "$containerNAMEfile" ;
        break;
    fi ;
fi



# END OF SANITY CHECKS

# DOWNLOAD UPDATED VERSION OF HELPER SCRIPT - IF AVAILABLE
touch "$mediadir"/vtt_2_fixit_json.sh
latest_version_sig=$(aws s3api head-object --profile $s3profile --bucket "$s3resourcebucket" --key 'vtt_2_fixit_json.sh' 2>/dev/null | jq -r '.ETag|ltrimstr("\"")|rtrimstr("\"")' ) ;
my_version_sig=$(openssl dgst -md5 "$mediadir"/vtt_2_fixit_json.sh | awk -F\= '{print $2}' | awk '{print $1}') ;
if [ "$my_version_sig" != "$latest_version_sig" ];
then
    aws s3 cp --profile $s3profile s3://"$s3resourcebucket"/vtt_2_fixit_json.sh - > "$mediadir"/vtt_2_fixit_json.sh  ;
else
    echo > /dev/null ;
fi 2>/dev/null ;

# DOWNLOAD UPDATED VERSION OF THIS SCRIPT - IF AVAILABLE
latest_version_sig=$(aws s3api head-object --profile $s3profile --bucket "$s3resourcebucket" --key "$myname" 2>/dev/null | jq -r '.ETag|ltrimstr("\"")|rtrimstr("\"")' ) ;
my_version_sig=$(openssl dgst -md5 "$0" | awk -F\= '{print $2}' | awk '{print $1}') ;
if [ "$my_version_sig" != "$latest_version_sig" ];
then
    aws s3 cp --profile $s3profile s3://"$s3resourcebucket"/"$myname" - > "$mediadir"/"$myname"  ;
    exit ;
else
    echo > /dev/null ;
fi 2>/dev/null ;

# upload any previous output products
if [ -d "$mediadir"/transcripts_failed_upload ]
then
    aws s3 cp --profile $s3profile --metadata ASR-operator="$USER" --recursive "$mediadir"/transcripts_failed_upload "s3://$s3outputbucket/" >> "$mediadir"/s3xfer.log && /bin/rm -rf "$mediadir"/transcripts_failed_upload ;
fi ;
if [ -d "$mediadir"/transcripts ] ;
then
    # begin jq operations to create phrase-level versions of JSON for fixitplus
    IFS=$'\n\b' ; # because white space in idiotic file names
    for tfile in $(ls -1 "$mediadir"/transcripts/*.vtt );
    do
        guid=$(basename "$tfile" | sed 's#'"$defaultS3prefix"'.#'"$defaultS3prefix"'-#1' | tr '_.' '\n' | head -1) ;
        "$mediadir"/vtt_2_fixit_json.sh "$tfile" > "$mediadir"/transcripts/"$guid"'-transcript.json' ;
        echo '# WORDS COUNT: ' >>  "$mediadir"/transcripts/stats.txt ;
        wc -w $(ls "$mediadir"/transcripts/*.txt | grep -v stats.txt ) >> "$mediadir"/transcripts/stats.txt ;
        echo '# FILE SYSTEM METADATA: ' >>  "$mediadir"/transcripts/stats.txt ;
        stat "$mediadir"/transcripts/* >> "$mediadir"/transcripts/stats.txt ;
        mkdir -p "$mediadir"/transcripts/"$guid" ;
        find "$mediadir"/transcripts -maxdepth 1 -type f -exec mv {} "$mediadir"/transcripts/"$guid"/ ';' ;
    done
    #
    # begin upload of transcripts folder to s3
    printf %s > "$s3xfererrfile" ;
    aws s3 cp --profile $s3profile --metadata ASR-operator="$USER" --recursive "$mediadir"/transcripts "s3://$s3outputbucket/" >> "$mediadir"/s3xfer.log 2> "$s3xfererrfile" ;
    if [ -s "$s3xfererrfile" ]
    then
        mkdir -p "$mediadir"/transcripts_failed_upload ;
        cp -R "$mediadir"/transcripts/ "$mediadir"/transcripts_failed_upload && /bin/rm -rf "$mediadir"/transcripts && open "$mediadir"/transcripts_failed_upload ;
        open -e "$s3xfererrfile" ;
        callForHelp "completed%20transcripts%20failed%20to%20upload%20%20%28Include%20the%20error%20report%20now%21%29"
        # exit ; # no upload now but OK to try to download and do another
    else
        /bin/rm -rf "$mediadir"/transcripts ;
    fi
fi

# tidy up when s3xfer.log > 1 MB
# the osascript call resolves to something like '/private/var/folders/63/1t13qp9x4bs019cr3_dsxjfhrc784f/T/TemporaryItems/'
if [ "$(du -k "$mediadir"/s3xfer.log | awk '{print $1}')" -gt 1000 ] ;
then
    cat "$mediadir"/s3xfer.log | gzip - >> "$(osascript -e 'posix path of (path to temporary items folder)')"s3xfer.log.gz && printf %s > "$mediadir"/s3xfer.log ;
fi

# remove any media files assumed to be already-processed by the docker image
/bin/rm -f "$mediadir"/*.{wav,mp3,mp4,WAV,MP3,MP4} ;

# work the S3 until we get a file to process
while [ -z "$(ls "$mediadir"/*.{wav,mp3,mp4,WAV,MP3,MP4} 2>/dev/null)" ];
do
    # get the first available listing from S3
    s3keyname=$(aws s3api list-objects --profile $s3profile --bucket "$s3listingbucket" --prefix "$thisS3prefix" --query 'Contents[0].Key' 2>/dev/null | jq -r '.|tostring' 2>/dev/null) ;
    if [ "$s3keyname" == 'null' ] ;
    then
        osascript -e 'display dialog "No media to process are found on S3 using prefix \"'"$thisS3prefix"'\"" with title "ERROR" with icon 0 buttons {"Help"} default button 1 giving up after 10' -e 'button returned of result' >/dev/null 2>&1 &
        exit ;
    fi
    # now "move" the listing file out of the common view of $prefix
    aws s3api copy-object --profile $s3profile --copy-source "$s3listingbucket"/"$s3keyname" --bucket "$s3listingbucket" --key "processing"-"$s3keyname"-"$USER"-"$starttime" --metadata-directive COPY --tagging-directive COPY  &&  aws s3api delete-object --profile $s3profile --bucket "$s3listingbucket" --key "$s3keyname" ;
    #
    # make sure all that went OK!
    listing=$(aws s3api head-object --profile $s3profile --output text --bucket "$s3listingbucket" --key "$s3keyname" 2>/dev/null ) ;
    if [ ! -z "$listing" ]
    then
        exit ; # it is still there for some reason
    fi

    # now check for an eligible media file
    s3headvalue=$(aws s3api head-object --profile $s3profile --output text  --bucket "$s3mediabucket" --key "$s3keyname" 2>/dev/null ) ;
    if [ ! -z "$s3headvalue" ] ;
    then
        # check to see if & how the media file is tagged;
        # a mismatch could suggest either an interrupted session by this user or a race condition with another user
        #
#        begin jq work
        s3tagsvalues=$(aws s3api get-object-tagging --profile $s3profile --bucket "$s3mediabucket" --key "$s3keyname" ) ;
        s3tagvalue=$(echo $s3tagsvalues | jq -r '.TagSet[]|select(.Key=="ASR-operator").Value') ;
        s3othertags=$(echo "$s3tagsvalues" | jq -r '.TagSet|map(select(.Key!="ASR-operator"))' ) ;
#        end jq work


        if [ -z "$s3tagsvalues" ] ;
        then
            aws s3api put-object-tagging --profile $s3profile --bucket "$s3mediabucket" --key "$s3keyname" --tagging 'TagSet=[{Key=ASR-operator,Value='"$USER"'}]' ;
        elif [ -z "$s3tagvalue" -a ! -z "$s3othertags" ]
        then
#            aws s3api put-object-tagging --profile $s3profile --bucket "$s3mediabucket" --key "$s3keyname" --tagging 'TagSet=[{Key=ASR-operator,Value='"$USER"'},'"$s3othertags"']' ;
            newtagset=$(echo "$s3othertags" | jq -r --arg USER "$USER" --argjson s3othertags "$s3othertags" '.+[{"Key":"ASR-operator","Value":$USER}] | {"TagSet":.}') ;
            aws s3api put-object-tagging --profile $s3profile --bucket "$s3mediabucket" --key "$s3keyname" --tagging "$newtagset" ;
        fi
        s3tagvalue=$(aws s3api get-object-tagging --profile $s3profile --output text  --bucket "$s3mediabucket" --key "$s3keyname" --query "TagSet[?Key=='ASR-operator'].Value") ;
        if [ "$s3tagvalue" == "$USER" ] ;
        then
            mkdir -p "$mediadir"/transcripts ;
            aws s3 cp --profile $s3profile s3://"$s3mediabucket"/"$s3keyname" "$mediadir"/"$s3keyname" && docker run --rm -v "$mediadir"/:/mymedia/ "$ASR_IMAGE" /bin/bash -c "ffprobe -hide_banner -pretty /mymedia/'$s3keyname' 2>&1 " > "$mediadir"/transcripts/stats.txt && echo "$starttime" > "$containerNAMEfile" && nice docker run  --name "$starttime" --rm -d -v "$mediadir"/:/mymedia/ -v $HOME/.cache/whisper/:/root/.cache/whisper/ "$ASR_IMAGE" whisper --model tiny.en --output_dir /mymedia/transcripts/ /mymedia/"$s3keyname" >/dev/null ;
            break;
        else
            aws s3api copy-object --profile $s3profile --bucket "$s3listingbucket" --copy-source "$s3listingbucket"/processing-"$s3keyname"-"$USER"-"$starttime" --key error-tagging-"$s3keyname"-"$USER"-"$starttime" --metadata-directive COPY --tagging-directive COPY ;
            aws s3api delete-object --profile $s3profile --bucket "$s3listingbucket" --key processing-"$s3keyname"-"$USER"-"$starttime" ;
                # "something unexpected went wrong is now recorded as an error in the listings"
        fi
    else
        aws s3api copy-object --profile $s3profile --bucket "$s3listingbucket" --copy-source "$s3listingbucket"/processing-"$s3keyname"-"$USER"-"$starttime" --key error-missing-"$s3keyname" --metadata-directive COPY --tagging-directive COPY ;
        aws s3api delete-object --profile $s3profile --bucket "$s3listingbucket" --key processing-"$s3keyname"-"$USER"-"$starttime" ;
    fi
    sleep 30; # in case nothing could be had from S3
done
EOF
```

```bash
# create an XML file on your local machine to dictate the scheduled execution of script `whispermedia.sh`

cat << 'EOF' > "$HOME"/Library/LaunchAgents/org.wgbh.mla.s3dockerwhisper.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
    </dict>
    <key>Label</key>
    <string>org.wgbh.mla.s3dockerwhisper</string>
    <key>Program</key>
    <string>/bin/bash</string>
    <key>ProgramArguments</key>
    <array>
        <string>-l</string>
        <string>-c</string>
        <string>"$HOME"/.docker/mnt/s3/whispermedia.sh</string>
    </array>
    <key>StartInterval</key>
    <integer>900</integer>
</dict>
</plist>
EOF
```

```bash
# copy/paste the following section into the terminal window and then press the enter key to enable the XML file to be used.

chmod 644 "$HOME"/Library/LaunchAgents/org.wgbh.mla.s3dockerwhisper.plist && launchctl load -w "$HOME"/Library/LaunchAgents/org.wgbh.mla.s3dockerwhisper.plist && launchctl start "$HOME"/Library/LaunchAgents/org.wgbh.mla.s3dockerwhisper.plist
```

Installation is complete! You can close Terminal.app if you're not going to use it for anything else.
Use the icon for Docker Desktop in the "system menu" area at the top (-right) of your screen; make sure it's there and running.
This system should run silently, periodically using aws to upload/download files and process them using docker and jq
Sometimes you might want to pause the background process, e.g., you need full power for video or to conserve power for battery; download and unzip and keep this attachment to run (double-click in Finder) "toggle_docker_asr.app" NOTE: if your system declines to run the app, then type the following (wait to press the enter key) into a window of application "Terminal"

xattr -c -r
then drag from Finder the afflicted "toggle_docker_asr.app" and drop into that Terminal window and then activate the Terminal window and press the enter key.

Double-clicking the app in Finder should then succeed.
