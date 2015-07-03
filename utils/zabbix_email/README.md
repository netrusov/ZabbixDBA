## Zabbix Email Sender
Custom email sender for Zabbix that attaches graphs to message.  
  
### Usage
Put **zabbix_email.pl** script to AlertScriptsPath directory and grant privileges to execute it to zabbix user.  
**Don't forget to change URL of Zabbix frontend, username and password!** 

```
### Option: AlertScriptsPath
#       Full path to location of custom alert scripts.
#       Default depends on compilation options.
#
# Mandatory: no
# Default:
# AlertScriptsPath=${datadir}/zabbix/alertscripts

AlertScriptsPath=/usr/lib/zabbix/alertscripts
```
  
Create new Media Type and name it whatever you want, select type **Script** and enter name of the script.
Now create new action for this media type and change default message to HTML template that you can find in **email_template.html**