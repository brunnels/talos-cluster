# Initial Login

-  When you first connect you will be presented with interface to create and admin user.
You can use whatever here because it will be disabled and not used.
There's just no current way to disable this.
-  After you login your user with oidc you will be a normal user.
To give your oidc user full admin rights you will need to edit the database record for your user in the users table and set rbac_roles = "{owner}"
