#!/bin/bash
#
# IMPORTANT >>>>>You need to get port, ip and feed_id right<<<<<
if [ "X$SNOWMIX" = X ] ; then
  echo "You need to set the SNOWMIX environment variable"
  exit 1
fi
if [ "X$SNOWMIX_PORT" = X ] ; then export SNOWMIX_PORT=9999 ;fi
if [ "X$SNOWMIX_IP" = X ] ; then export SNOWMIX_IP=127.0.0.1 ;fi

if [ $# -lt 1 ] ; then
  echo "Missing argument\nUsage $0 <feed id> [<audio feed id> [<input file>]"
  echo "Setting audio feed to 0 disables audio"
  exit 1
fi

# Set video feed and audio feed id
feed_id=$1
if [ $# -lt 2 ] ; then
  audio_feed_id=0
else
  audio_feed_id=$2
fi

if [ $# -gt 2 ] ; then
  if [ -s $3 ] ; then
    source=$3
  else
    echo "Can no read file $3"
    exit 1
  fi
else
  if [ -f $SNOWMIX/test/big_buck_bunny_720p_H264_AAC_25fps_3400K.MP4 ] ; then
    source=$SNOWMIX/test/big_buck_bunny_720p_H264_AAC_25fps_3400K.MP4
  else
    if [ -f $SNOWMIX/test/LES_TDS_launch.mp4 ] ; then
      source=$SNOWMIX/test/LES_TDS_launch.mp4
    else
      echo 'Could not find any video test file.'
      exit 1
    fi
  fi
fi

# Check for SNOWMIX variable and the snowmix and gstreamer settings
if [ ! -f "$SNOWMIX/scripts/gstreamer-settings" -o ! -f "$SNOWMIX/scripts/snowmix-settings" ] ; then
  echo "Can not find the the file scripts/gstreamer-settings or scripts/snowmix-settings"
  echo "in the directory set by the enviroment variable SNOWMIX"
  echo "You need to se the environment variable SNOWMIX to the base of the Snowmix installed directory"
  exit 1
fi

# Load the Snowmix and GStreamer settings
. $SNOWMIX/scripts/gstreamer-settings
. $SNOWMIX/scripts/snowmix-settings
# This will set
# a) feed_rate
# b) feed_channels
# c) feed_control_pipe
# d) feed_width
# e) feed_height
# f) ctrsocket
# g) system_width
# h) system_height
# i) ratefraction
# j) snowmix
# k) channels
# l) rate


if [ X$feed_control_pipe = X -o X$system_width = X -o X$system_height = X ] ; then
  echo Failed to get control pipe or width or height from running snowmix
  exit 1
fi

#echo "Snowmix Geometry        : $system_width x $system_height"
#echo "Snowmix control socket  : $ctrsocket"
#echo "Video feed geometry     : $feed_width x $feed_height"
#echo "Video control socket    : $feed_control_pipe"
#echo "Video and audio feed id : $feed_id $audio_feed_id"

if [ X$feed_rate = X -o X$feed_channels = X ] ; then
  echo Failed to get rate or channels from running snowmix
  echo Disabling audio
fi

SRC="filesrc location=$source ! $decodebin name=decoder ! $VIDEOCONVERT "
SHMSIZE='shm-size='`echo "$feed_width * $feed_height * 4 * 30"|bc`
SHMOPTION="wait-for-connection=0 sync=true"
SHMSINK1="shmsink socket-path=$feed_control_pipe $SHMSIZE $SHMOPTION"
#SCALE="$VIDEOCONVERT ! videoscale ! $VIDEOCONVERT"
SCALE="videoscale add-borders=0 ! $VIDEOCONVERT"
AUDIOFORMAT="$AUDIOS16LE"', rate='$feed_rate', channels='$feed_channels
VIDEOFORMAT=$VIDEOBGRA', width='$feed_width', height='$feed_height', framerate='$ratefraction
VIDEOFORMAT=$VIDEOBGRA', width='$feed_width', height='$feed_height


# Remove the named pipe if it exist
rm -f $feed_control_pipe
snowmix=`ps c |cut -c28-34 | grep snowmix | head -1`
snowmix=snowmix
if [ X$snowmix != X ] ; then
  if [ X$feed_rate != X -a X$feed_channels != X ] ; then
echo $gstlaunch -q $SRC ! \
videorate ! $SCALE ! $VIDEOFORMAT ! $SHMSINK1 decoder. \
! queue ! audioconvert ! audioresample ! $AUDIOFORMAT ! fdsink fd=1 sync=true
    (
echo 'audio feed ctr isaudio '$audio_feed_id
$gstlaunch -v $SRC ! \
videorate ! $SCALE ! $VIDEOFORMAT ! $SHMSINK1 decoder. \
! queue ! audioconvert ! audioresample ! $AUDIOFORMAT ! fdsink fd=3 sync=true 3>&1 1>&2
    ) | nc $SNOWMIX_IP $SNOWMIX_PORT
  else
$gstlaunch -q $SRC ! \
$SCALE		! \
$VIDEOFORMAT	! \
$SHMSINK1  
  fi
else
  echo Snowmix is not running. Quitting $0
  exit 1
fi
exit
