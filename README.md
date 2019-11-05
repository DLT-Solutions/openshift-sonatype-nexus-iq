# Sonatype IQ Server on OpenShift

In order to operate this you'll need a license.  Contact [Fierce Software](https://fiercesw.com/request-a-demo) for a trial license.

## Deployment - Via OC CLI

This is actually not too bad to deploy - a bit more manual than the Nexus deployment, but still not hard.

1. Have Sonatype Nexus deployed already in your namespace/project
2. Modify the config.yaml file to suit your needs, keeping the /sonatype-work and license paths the same (unless you update the respective parts in the shell script and OpenShift Template)
3. Import your license file (rename to iq-server-license.lic) to this directory
4. Switch to your CI/CD namespace or where you have Nexus/want IQ

  ```
  $ oc project nexus-iq-server
  ```

5. Create a ConfigMap from the config.yaml file:

  ```
  $ oc create configmap --from-file=config.yml iq-server-config
  ```

6. Create a Secret from the license file:

  ```
  $ oc create secret generic iq-server-license --from-file=iq-server-license.lic
  ```

7. Deploy IQ Server

  ```
  $ oc create -f iq-server.yml   #Ephermial
  $ oc create -f iq-server-persistent.yml   # Persistent Data Volume backed
  ```
  
8. ??????
9. PROFIT!!!!1

## LDAP

The whole point of Nexus Platform is to centrally manage components and repositories across your organization so every developer shouldn't have their own Nexus/IQ Server.  The easiest way to deploy IQ Server centrally is via LDAP.

***NOTE:*** You will need to have deployed Nexus IQ Server via the Persistent template as this requires restarting the container.

### Stuffing the container with an SSL Certificate

Nexus allows you to pull SSL Certificates into the Trusted Keystore via the GUI.  IQ Server does not. :(
If you are using a self-signed SSL certificate for IDM/LDAP then you need to pull that SSL certificate into a writeable keystore.  There is a script that can create a keystore that is writable, and stuff it with extra SSL certificates.  To do so, supply the script a list of space separated domains and ports to pull SSL certificates from.

```
$ oc exec $(oc get pod -o name | grep nexus-iq-server | awk '!/deploy/ && !/hook/' | sed 's/pod\///') -- curl -L -sS -o /sonatype-work/ss-ca-puller.sh https://raw.githubusercontent.com/kenmoini/openshift-sonatype-nexus-iq/master/scripts/ss-ca-puller.sh
$ oc exec $(oc get pod -o name | grep nexus-iq-server | awk '!/deploy/ && !/hook/' | sed 's/pod\///') -- chmod +x /sonatype-work/ss-ca-puller.sh
$ oc exec $(oc get pod -o name | grep nexus-iq-server | awk '!/deploy/ && !/hook/' | sed 's/pod\///') -- /sonatype-work/ss-ca-puller.sh idm.example.com:636
```

That will copy over the script and run a few commands that'll pull it into your custom IQ Server JRE keystore.  However, you're not done yet because on OpenShift containers don't run as root and you can't write to the system keystore :)

Instead, that script will create a copy of the system keystore in a writable path at ```/sonatype-work/.cacerts/cacerts```.

Next, in order for IQ Server to load the custom keystore it must be added to the JAVA_OPTS on the IQ Server DeploymentConfig...

You can do this a few different ways - by modifying the ```iq-server-persistent.yml``` file that was used to deploy this and then reapply it to the cluster to update the manifest, or by just modifying it in the Web UI.  That's way easier and faster.

1. In the OCP Web UI, navigate to the project with IQ Server, click on its DeploymentConfig
2. Click the **Environment** tab
3. Add the following to the end of your JAVA_OPTS environment variable

```
-Djavax.net.ssl.trustStore=/sonatype-work/.cacerts/cacerts
```

*Mine looks like ```-Djava.util.prefs.userRoot=/sonatype-work/javaprefs -Djavax.net.ssl.trustStorePassword=changeit -Djavax.net.ssl.trustStore=/sonatype-work/.cacerts/cacerts```*

Then click ***Save***.  Wait a few moments and with any luck, IQ Server will restart and JavaX will consume the new CA Certificate keystore that now includes your self-signed IDM certificate, allowing the connection of LDAPS.


### Configure LDAP

1. Log into IQ Server as an Admin, click on the **System Preferences** cog button to the right of the bar at the top.
2. Use the drop down to choose **LDAP**
3. Click ***Add a Server***
4. Configure the Connection as follows *(assuming Red Hat Identity Management setup for LDAPS)*:
  - **Name**: IDM
  - **Protocol**: LDAPS
  - **Hostname**: idm.example.com
  - **Port**: 636
  - **Search Base**: dc=example,dc=com
  - **Authentication Method**: SIMPLE
  - **SASL Realm**: *(blank)*
  - **Username or DN**: CN=Directory Manager
  - **Password**: duh
  - **Timeouts**: Default is fine
5. Click ***Test Connection*** and if successful, click **Save**
6. Now click the User and Group tab and set the configuration as such:
  - **Configuration template**: Generic LDAP Server
  - **Base DN**: CN=accounts
  - **Include User Subtree?**: *Checked*
  - **Object class**: inetOrgPerson
  - **User filter**: *(blank)*
  - **User ID attribute**: uid
  - **Real name attribute**: cn
  - **Email attribute**: mail
  - **Password attribute**: *(blank)*
  - **Group type**: Dynamic Groups
  - **Group member of attribute**: memberOf
7. Click ***Check user mapping*** to ensure it can enumerate the targeted group of users
8. Click ***Check login*** and select a random user from LDAP to test
9. Click ***Save***
10. Log out and log in as one of the users from LDAP for a final test.  You should see nothing because the user group has not been mapped to a role yet.