# chkconfig: 0123456 99 01
# description: applying policy for ds_agent during restart/reboot
##  chkconfig ds_agent_policy --level 12345 on
##  chkconfig ds_agent_policy --level 06 off

start() {
        echo -n $"Applying policy during start-up: " >> /tmp/ds_command_status.log
        touch /var/lock/subsys/ds_agent_policy
        echo `date` >> /tmp/ds_command_status.log
        /opt/ds_agent/dsa_control -r >> /tmp/ds_command_status.log
		/opt/ds_agent/dsa_control -a dsm://hb.genpact.com:443/ "policyid:69" >> /tmp/ds_command_status.log
        RETVAL=$?
        if [ "$RETVAL" == "0" ]; then
                echo "success" >> /tmp/ds_command_status.log
        else
               echo "failure" >> /tmp/ds_command_status.log
        fi
        echo
        return 0
}

stop() {
        echo -n $"nothing to do regarding policy: " >> /tmp/ds_command_status.log
        echo `date` >> /tmp/ds_command_status.log
        rm -f /var/lock/subsys/ds_agent_policy
        RETVAL=$?
        sleep 2
        if [ "$RETVAL" == "0" ]; then
                echo "success" >> /tmp/ds_command_status.log
        else
                echo "failure" >> /tmp/ds_command_status.log
        fi
        echo
        return 0
}

restart() {
        stop
        start
}


case "$1" in
  start)
        start
        ;;
  status)
        status ds_agent
        ;;
  stop)
        stop
        ;;
  restart)
        restart
        ;;
  *)
        echo $"Usage: $0 {start|stop|restart}"
        exit 1
esac

exit $?