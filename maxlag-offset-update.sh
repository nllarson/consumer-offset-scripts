#!/bin/sh

# Plan
# 1) Determine consumer group max lag topic A (old)
# 2) Create / Shift consumer group offsets on Topic B (new) to Max Lag (found in #1) + OFFSET BACKOFF (defined in script)
#

CONFLUENT_PATH=/Users/nllarson/tools/confluent/current/bin
CONFLUENT_CONFIG_FILE=kafka.properties
OFFSET_BACKOFF=100

usage()
{
    echo "Usage: maxlag-offset-update.sh <consumer group> <topicA> <topicB>";
    exit 1;
}

if [ $# -ne 3 ] ; then
    usage
else
    consumerGroup=$1
    topicA=$2
    topicB=$3
fi

## DEBUG
# echo "Consumer Group: $consumerGroup";
# echo "Topic A: $topicA";
# echo "Topic B: $topicB";

# Find Current Offsets for Consumer Group on Topic A
aOffsets=`$CONFLUENT_PATH/kafka-consumer-groups --command-config $CONFLUENT_CONFIG_FILE  --bootstrap-server $(grep "^\s*bootstrap.server" $CONFLUENT_CONFIG_FILE | tail -1)  --describe --group $consumerGroup`
partitionLag=($(echo "$aOffsets" |  awk 'NR>2 {printf "%s,%s\n", $3, $6}'))

bOffsets=()
maxLag=0

# Find Latest Offset for Topic B
for lag in "${partitionLag[@]}"
do
    IFS=','
    read -ra line <<< "$lag"

    lastOffset=`$CONFLUENT_PATH/kafka-run-class kafka.tools.GetOffsetShell \
        --broker-list $(grep "^\s*bootstrap.server" $CONFLUENT_CONFIG_FILE | tail -1) \
        --command-config $CONFLUENT_CONFIG_FILE \
        --topic $topicB \
        --partitions ${line[0]} | awk 'BEGIN {FS=":";} {print $3}'`

    bOffsets+=("${line[0]},${lastOffset}")
    

done

echo "-----------"
echo "\n"
echo "\n"
echo "\n"

# Display Results
echo "Topic A: ${topicA} Current Lag for Consumer Group ${consumerGroup}"
for lag in "${partitionLag[@]}"
do
    IFS=','
    read -ra line <<< "$lag"
    echo "Partition: ${line[0]} -- Consumer Lag: ${line[1]}" 

    if (("${line[1]}" >= "$maxLag"))
    then
        maxLag=${line[1]};
    fi  
done

echo "\n"
echo "Max Lag: ${maxLag}"
echo "\n"

echo "Topic B: ${topicB} - Offsets "
for bOff in "${bOffsets[@]}"
do
    IFS=','
    read -ra line <<< "$bOff"
    echo "Partition: ${line[0]} -- Latest Offset: ${line[1]} -- Set Offset: $((${line[1]} - (${maxLag} + ${OFFSET_BACKOFF})))"   
done

echo "\n"
echo "Consumer Group Update Statements"
echo "---------------------------------"

echo "kafka-consumer-groups --bootstrap-server $(grep "^\s*bootstrap.server" $CONFLUENT_CONFIG_FILE | tail -1) --group $consumerGroup --topic $topicB --reset-offsets --shift-by -$((${maxLag} + ${OFFSET_BACKOFF})) --execute"
















