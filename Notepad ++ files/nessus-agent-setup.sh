# chkconfig: 0123456 99 01
# description: linking nessus agent at startup and unlinking during shutdown or restart/reboot
##  chkconfig nessus_agent_setup --level 12345 on
##  chkconfig nessus_agent_setup --level 06 off

start() {
        echo -n $"Linking Nessus Agent services: " >> /tmp/nessus_command_status.log
        touch /var/lock/subsys/nessus_agent_setup
        echo `date` >> /tmp/nessus_command_status.log
        /opt/nessus_agent/sbin/nessuscli agent link --key=9d4777f71733214d2a35566bd5f4bee3fda2b19462083c5f692dc86a2306d771 --host=cloud.tenable.com --port=443 --groups="PVAI" >> /tmp/nessus_command_status.log
         RETVAL=$?
        if [ "$RETVAL" == "0" ]; then
                echo "success" >> /tmp/nessus_command_status.log
        else
               echo "failure" >> /tmp/nessus_command_status.log
        fi
        echo
        return 0
}

stop() {
        echo -n $"Unlinking Nessus Agent services: " >> /tmp/nessus_command_status.log
        echo `date` >> /tmp/nessus_command_status.log
        /opt/nessus_agent/sbin/nessuscli agent unlink >> /tmp/nessus_command_status.log
        rm -f /var/lock/subsys/nessus_agent_setup
        RETVAL=$?
        sleep 2
        if [ "$RETVAL" == "0" ]; then
                echo "success" >> /tmp/nessus_command_status.log
        else
                echo "failure" >> /tmp/nessus_command_status.log
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
        status nessusd
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