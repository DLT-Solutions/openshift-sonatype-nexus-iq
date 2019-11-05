# Sonatype IQ Server on OpenShift

In order to operate this you'll need a license.  Contact [Fierce Software](https://fiercesw.com/request-a-demo) for a trial license.

## Deployment - Via OC CLI

This is actually not too bad to deploy - a bit more manual than the Nexus deployment, but still not hard.

1. Have Sonatype Nexus deployed already in your namespace/project
2. Modify the config.yaml file to suit your needs, keeping the /sonatype-work and license paths the same (unless you update the respective parts in the shell script and OpenShift Template)
3. Import your license file (rename to iq-server-license.lic) to this directory
4. Switch to your CI/CD namespace or where you have Nexus/want IQ
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
  - **Username or DN**: CN=Directory Manager
  - **Password**: duh
  - **Connection Rules**: Default is fine
5. Click ***Verify Connection*** and if successful, click **Next**
6. Now set the User and Group configuration as such:
  - **Configuration template**: Generic LDAP Server
  - **Base DN**: CN=accounts
  - **User subtree**: *Checked*
  - **Object class**: inetOrgPerson
  - **User filter**: *(blank)*
  - **User ID attribute**: uid
  - **Real name attribute**: cn
  - **Email attribute**: mail
  - **Password attribute**: *(blank)*
  - **Map LDAP groups as roles**: *Checked*
  - **Group type**: Dynamic Groups
  - **Group member of attribute**: memberOf
7. Click ***Verify user mapping*** to ensure it can enumerate the targeted group of users
8. Click ***Verify login*** and select a random user from LDAP to test
9. Click ***Save***
10. Log out and log in as one of the users from LDAP for a final test.  You should see nothing because the user group has not been mapped to a role yet.