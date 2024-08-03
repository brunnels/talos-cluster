## Eclipse Che

## THIS WON'T WORK
- The operator chart doesn't have all dependencies.  You must install first with chectl then you can keep the CheCluster in flux if you want.
- see https://github.com/eclipse-che/che/issues/23049

#### Getting it to work with Authelia
1.  Ensure ingress-nginx helm chart value controller.allowSnippetAnnotations=true is set
1.  Generate and add a new external-secret provided oidc client secret
1.  Add kubeapi oidc client config to authelia
    ```yaml
          - client_id: kubeapi
            client_name: Kubeapi
            client_secret: "{{ .KUBEAPI_OIDC_CLIENT_SECRET }}"
            scopes: ["openid", "profile", "groups", "email", "offline_access"]
            redirect_uris: ["https://che.${SECRET_DOMAIN}/oauth/callback"]
            grant_types: ["refresh_token", "authorization_code"]
            response_types: ["code"]
    ```
1.  Patch Talos controller to add kubeapi oidc client configuration
    ```yaml
    cluster:
      apiServer:
        extraArgs:
          oidc-client-id: kubeapi
          oidc-issuer-url: https://auth.${SECRET_DOMAIN}
          oidc-username-claim: email
          oidc-groups-claim: groups
          oidc-username-prefix: "oidc:"
          oidc-groups-prefix: "oidc:"
    ```
    -  You'll probably need to add talenv.sops.yaml to define the SECRET_DOMAIN for talhelper
1.  Review and update `eclipse-che/operator/cluster-config/checluster.yaml advancedAuthorization for your users and groups
