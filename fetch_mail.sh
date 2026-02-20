#!/bin/bash

# remove loog files if they exist
cd ~/.zetta.d

echo "Starting mail fetch..."

# record start time
start_time=$(date +"%Y-%m-%d %H:%M:%S")

# Run programs in the background and redirect output to log files
/usr/local/opt/isync/bin/mbsync  -V gmail-misterchiply > fetch_chiply.log 2>&1 &
/usr/local/opt/isync/bin/mbsync  -V gmail-charliechristopherbaker > fetch_admin.log 2>&1 &
/usr/local/opt/isync/bin/mbsync  -V gmail-charliebkr707 > fetch_main.log 2>&1 &

# Wait for both programs to finish
wait

# record end time
end_time=$(date +"%Y-%m-%d %H:%M:%S")

echo "Fetching complete. Logs:"

echo "chiply log:"
cat fetch_chiply.log
echo "----------------------"

echo "admin log:"
cat fetch_admin.log
echo "----------------------"

echo "main log:"
cat fetch_main.log
echo "----------------------"

echo "Start time: $start_time"
echo "End time: $end_time"
# compute duration and present in hour:minute:second format
# date: illegal option -- d
start_sec=$(date -j -f "%Y-%m-%d %H:%M:%S" "$start_time" +"%s")
end_sec=$(date -j -f "%Y-%m-%d %H:%M:%S" "$end_time" +"%s")
duration=$((end_sec - start_sec))

hours=$((duration / 3600))
minutes=$(( (duration % 3600) / 60 ))
seconds=$((duration % 60))
printf "Duration: %02d:%02d:%02d\n" $hours $minutes $seconds
echo "Mail fetch process completed."

