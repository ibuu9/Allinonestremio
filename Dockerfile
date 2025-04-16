
services:
  warp:
    image: caomingjun/warp:latest
    container_name: warp
    restart: unless-stopped
    user: root
    ports:
      - "1080:1080"
    cap_add:
      - NET_ADMIN
    networks:
      - proxy
    # Security improvements
    security_opt:
      - no-new-privileges:true
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"

  traefik:
    image: traefik:v3.0
    container_name: traefik
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
      - "8080:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./letsencrypt:/letsencrypt
      - ./traefik-logs:/var/log/traefik
    command:
      - "--api.insecure=true"  # Consider securing this or disabling in production
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--providers.docker.network=proxy"
      - "--entryPoints.web.address=:80"
      - "--entryPoints.websecure.address=:443"
      - "--entryPoints.web.http.redirections.entryPoint.to=websecure"
      - "--entryPoints.web.http.redirections.entryPoint.scheme=https"
      - "--certificatesresolvers.letsencrypt.acme.tlschallenge=true"
      - "--certificatesresolvers.letsencrypt.acme.email=ibaadnewton1@gmail.com"
      - "--certificatesresolvers.letsencrypt.acme.storage=/letsencrypt/acme.json"
      - "--accesslog=true"
      - "--accesslog.filepath=/var/log/traefik-access.log"
      - "--accesslog.filters.statuscodes=100-599"
      - "--accesslog.fields.headers.defaultmode=keep"
      - "--log.level=INFO"  # Changed from DEBUG for production
      - "--serverstransport.insecureskipverify=true"  # Needed for warp proxy
    networks:
      - proxy
    # Security improvements
    security_opt:
      - no-new-privileges:true
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"

  mediaflow-proxy:
    image: mhdzumair/mediaflow-proxy
    container_name: mediaflow-proxy
    restart: unless-stopped
    expose:
      - 8888
    environment:
      API_PASSWORD: "Hansabhen1@"  # Consider using Docker secrets for passwords
      PROXY_URL: "http://warp:1080"
      MAX_CONCURRENT_STREAMS: "16"
      TRANSPORT_ROUTES: '{ "https://torrentio.strem.fun": { "proxy": true } }'
    ulimits:
      nofile:
        soft: 65535
        hard: 65535
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.mediaflow.rule=Host(`ibuumediaflow.duckdns.org`)"
      - "traefik.http.routers.mediaflow.entrypoints=websecure"
      - "traefik.http.routers.mediaflow.tls.certresolver=letsencrypt"
      - "traefik.http.services.mediaflow.loadbalancer.server.port=8888"
      # Security headers
      - "traefik.http.middlewares.mediaflow-headers.headers.sslredirect=true"
      - "traefik.http.middlewares.mediaflow-headers.headers.stsSeconds=31536000"
      - "traefik.http.middlewares.mediaflow-headers.headers.browserxssfilter=true"
      - "traefik.http.routers.mediaflow.middlewares=mediaflow-headers"
    networks:
      - proxy
    depends_on:
      - warp

  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - portainer_data:/data
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.portainer.rule=Host(`portforibuu.duckdns.org`)"
      - "traefik.http.routers.portainer.entrypoints=websecure"
      - "traefik.http.routers.portainer.tls.certresolver=letsencrypt"
      - "traefik.http.services.portainer.loadbalancer.server.port=9000"
      - "traefik.http.middlewares.portainer-auth.basicauth.users=admin:$$apr1$$ktXLGE2F$$/P/vMLKfCnlF3ni84/os11"
      - "traefik.http.routers.portainer.middlewares=portainer-auth"
      # Security headers
      - "traefik.http.middlewares.portainer-headers.headers.sslredirect=true"
      - "traefik.http.routers.portainer.middlewares=portainer-headers"
    networks:
      - proxy
    security_opt:
      - no-new-privileges:true

  aiostreams:
    image: ghcr.io/viren070/aiostreams:latest
    container_name: aiostreams
    restart: unless-stopped
    expose:
      - 3000
    environment:
      - ADDON_PROXY=http://warp:1080
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.aio.rule=Host(`aiostremibuu.duckdns.org`)"
      - "traefik.http.routers.aio.entrypoints=websecure"
      - "traefik.http.routers.aio.tls.certresolver=letsencrypt"
      - "traefik.http.services.aio.loadbalancer.server.port=3000"
      # Security headers
      - "traefik.http.middlewares.aio-headers.headers.sslredirect=true"
      - "traefik.http.routers.aio.middlewares=aio-headers"
    networks:
      - proxy
    depends_on:
      - warp

  duckdns:
    image: linuxserver/duckdns
    container_name: duckdns
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=UTC
      - SUBDOMAINS=ibuumediaflow,aiostremibuu,portforibuu,statusforibuu
      - TOKEN=43cb2b48-35bc-4dfb-a08b-55f4b3e7884b
    restart: unless-stopped
    networks:
      - proxy
    user: "1000:1000"
    # Security improvements
    read_only: true
    tmpfs:
      - /tmp
      - /run
    volumes: 
      - ./duckdns/config:/config

  uptime-kuma:
    image: louislam/uptime-kuma
    container_name: uptime-kuma
    restart: unless-stopped
    volumes:
      - uptime_kuma_data:/app/data
      - /var/run/docker.sock:/var/run/docker.sock:ro
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.uptime-kuma.rule=Host(`statusforibuu.duckdns.org`)"
      - "traefik.http.routers.uptime-kuma.entrypoints=websecure"
      - "traefik.http.services.uptime-kuma.loadbalancer.server.port=3001"
      - "traefik.http.routers.uptime-kuma.tls.certresolver=letsencrypt"
      # Security headers
      - "traefik.http.middlewares.uptime-headers.headers.sslredirect=true"
      - "traefik.http.routers.uptime-kuma.middlewares=uptime-headers"
    networks:
      - proxy
    security_opt:
      - no-new-privileges:true

networks:
  proxy:
    driver: bridge
    # Optional: Enable IPAM for better network management
    ipam:
      driver: default
      config:
        - subnet: 172.20.0.0/16

volumes:
  warp-data:
  portainer_data:
  uptime_kuma_data:
