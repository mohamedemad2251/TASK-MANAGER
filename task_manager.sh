#!/usr/bin/bash
#The shebang, to define the type of shell used.

#======================================CONFIGURATIONS (HERE FOR NOW)===============================================
declare -x TASK_MANAGER_WHITESPACE=12   #Number of whitespaces between each category
#==================================================================================================================

#======================================DEFINITIONS===============================================
declare stat_pid=0          #Index in array allocated for extracting PID
declare stat_name=1         #Index in array allocated for extracting NAME
declare stat_ppid=3         #Index in array allocated for extracting PPID
declare stat_utime=13       #Index in array allocated for extracting time elapsed for the process in user space
declare stat_stime=14       #Index in array allocated for extracting time elapsed for the process in kernel space
declare stat_starttime=21   #Index in array allocated for extracting start time of the process after system boot
declare stat_virt=22        #Index in array allocated for extracting VIRTUAL MEMORY

declare first_element=0

declare read_from_stat=""
declare read_from_uptime=""

declare percentage=100
declare kb_size=1024        #Size to convert B to KB
declare clk_tck=$(getconf CLK_TCK)

declare time_by_process_clk
declare starttime_clk
declare cpu_percentage

declare tasks_array=()
#================================================================================================

adjust_line_format()
{
    index=$1
    local line=""   #This variable will hold the line string that will be our output (Anything passed by positional parameters but formatted the correct way)
    for index; do   #This syntax here is simple: We assigned index with the first positional parameter "$1" and THEN we looped on it, it implicitly looped on "$@" which is an array of ALL positional parameters passed to the function
        line="${line}$index"    #Simply, we're appending strings (so if we have "Hello " & "World", the new line will be "Hello World")
        for spaces in $(seq 0 "$((TASK_MANAGER_WHITESPACE - ${#index}))" ); do  #Starting from 0 till (WHITESPACE - size of string inside the positional parameter)
            line="${line} "     #Here, we're appending the already existing line with a space ' ', you can notice it.
        done 
    done
    echo "$line"    #Return the formatted line
}

while true; do
    #adjust_line_format "PID" "USER" "PPID" "VIRT (KB)" "CPU%" "NAME"
    tasks_array=()  #Clear the array, since this is a while loop, the array will forever append & the output won't be correct.
    tasks_array+=("$(adjust_line_format "PID" "USER" "PPID" "VIRT (KB)" "CPU%" "NAME")")

    #=====================================STAT PARSING===============================================
    for filename in $(ls -1 /proc/ | tr '\n' ' ' | grep -o -E '[0-9]+'); do #For this line, we're simply using ls to list, then passing the result to have whitespaces, then removing everything that is not between 0-9 (i.e. not a process)
        if [ -f "/proc/$filename/stat" ]; then
            read_from_stat=$(cat /proc/"$filename"/stat)   #'cat' returns a string, so we're storing it in a string variable
            IFS=' ' read -ra proc_stat_array <<< "$read_from_stat"
            #I'll breakdown this line into the following
            #IFS: Internal Field Seperator, used to identify which character SPLITS words in a string, the default is ' ' (i.e. whitespace) (Like how we read "Hello World" as "Hello" & "World")
            #' ': We're overwriting the IFS to be assigned as ' ', I don't know why it's placed this way but that's what it means (Should be okay by default)
            #read: A command that reads a line, here, we're reading from $read_from_stat
            #"<<<": Called a "here string". Equivalent to echo "$read_from_stat | read -ra proc_stat_array"
            #"-ra": 2 options: -r for treating the backslash ('\') as a literal backslash.  -a To put the result in an array

            proc_stat_array[stat_name]=${proc_stat_array[$stat_name]##*(}    #Extract from the end till the '(' (It's included)
            proc_stat_array[stat_name]=${proc_stat_array[$stat_name]%%)*}    #Extract from the beginning till the ')' (It's included)
            #Now, this has removed both the parentheses on the process's name

            time_by_process_clk=$(("${proc_stat_array[stat_utime]}" + "${proc_stat_array[stat_stime]}"))
            time_by_process_sec=$(echo "scale=2; $time_by_process_clk / $clk_tck" | bc -l)  #bc stands for basic calculator because bash doesn't handle floating points. scale=2 is for a 2-decimal precision after the decimal point
            #The echo is therefore printed, but instead the screen (stdout), we're piping it to the basic calculate 'bc'
            read_from_uptime=$(cat /proc/uptime)   #'cat' returns a string, so we're storing it in a string variable
            IFS=' ' read -ra system_uptime_array <<< "$read_from_uptime"
            system_uptime_sec=${system_uptime_array[$first_element]}
            starttime_clk=${proc_stat_array[stat_starttime]}
            starttime_sec=$(echo "scale=2; $starttime_clk / $clk_tck" | bc -l)
            time_elapsed_sec=$(echo "$system_uptime_sec-$starttime_sec" | bc -l)
            cpu_percentage=$(echo "scale=2; ($time_by_process_sec * $percentage) / $time_elapsed_sec" | bc -l)

            proc_stat_array[stat_virt]=$((proc_stat_array[stat_virt]/kb_size))

        #=======================================PRINTING=================================================
            proc_user=$(cat /proc/"$filename"/loginuid | getent passwd)    #use 'cat' to get the user id THEN, search the ID & store it in proc_user using 'getent passwd'
            proc_user=${proc_user%%:*}      #Multiple things show in proc_user, extract the first word only which is the user's name (i.e. till the ':')

            tasks_array+=("$(adjust_line_format "${proc_stat_array[$stat_pid]}" "$proc_user" "${proc_stat_array[$stat_ppid]}" "${proc_stat_array[$stat_virt]}" "$cpu_percentage" "${proc_stat_array[$stat_name]}")")
        #================================================================================================
        else
            continue
        fi
    done
    #================================================================================================
    clear   #Needs to be changed to a buffer?
    printf "%s\n" "${tasks_array[@]}"
    sleep 1 #Needs to be changed
done

#TODO: Make it interactive & real-time
#TODO: Add killing signals & options