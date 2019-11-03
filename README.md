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

## Container Image Additions

The container, found at [https://hub.docker.com/r/kenmoini/openshift-sonatype-nexus](https://hub.docker.com/r/kenmoini/openshift-sonatype-nexus) has some additional bits stuffed into the image.

### LDAP and Self-Signed Certificates
JavaX doesn't accept self-signed certificates when using LDAPS connectivity.  In order to get past this for normal LDAP deployments, you must import the certificates into the JRE keystore.

To do this, there is a script, ```ss-ca-puller.sh```, that will loop through a list of hosts, connect and retrieve their SSL certificate, then add it to the JRE keystore.

To add your own self-signed SSL certificates to the keystore you will need to modify the domain list in this Dockerfile and build the Docker image yourself - I do so everytime I use this for a workshop because the LDAP/RH IDM server is ephemeral and certificates change from workshop to workshop.

## LDAP

The whole point of Nexus Repo Manager is to centrally manage components and repositories across your organization so every developer shouldn't have their own Nexus.  The easiest way to deploy Nexus centrally is via LDAP.

### Configure LDAP

1. Log into Nexus as an Admin, click on the ***Settings*** cog button to the left of the Search bar at the top.
2. Use the pane to the left to navigate to ```Administration > Security > LDAP```
3. Click ***Create Connection***
4. Configure the Connection as follows *(assuming Red Hat Identity Management setup for LDAPS)*:
  - **Name**: IDM
  - **Protocol**: LDAPS
  - **Hostname**: idm.example.com
  - **Port**: 636
  - **Search Base**: dc=example,dc=com
  - **Authentication Method**: Simple Authentication
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