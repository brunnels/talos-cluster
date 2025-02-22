### Notes for dashbrr

When you first add to your manifests you'll need to import the config because the discovery isn't good.


Exec into the container and do the following:
- cd /cache and create file services.yaml with the following content depending on what is in your external-secret
```yaml
services:
  radarr:
    - url: "http://radarr.downloads"
      apikey: "${DASHBRR_RADARR_API_KEY}"
      access_url: "https://radarr.${SECRET_DOMAIN}"
  sonarr:
    - url: "http://sonarr.downloads"
      apikey: "${DASHBRR_SONARR_API_KEY}"
      access_url: "https://sonarr.${SECRET_DOMAIN}"
  prowlarr:
    - url: "http://prowlarr.downloads"
      apikey: "${DASHBRR_PROWLARR_API_KEY}"
      access_url: "https://prowlarr.${SECRET_DOMAIN}"
  overseerr:
    - url: "http://overseerr.media"
      apikey: "${DASHBRR_OVERSEERR_API_KEY}"
      access_url: "https://overseerr.${SECRET_DOMAIN}"
  plex:
    - url: "http://plex.media"
      apikey: "${DASHBRR_PLEX_API_KEY}"
      access_url: "https://plex.${SECRET_DOMAIN}"

```

- Next run the following command to import the services into the database:

`dashbrr config import services.yaml`
