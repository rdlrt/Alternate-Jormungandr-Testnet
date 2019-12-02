# Important:
- Intention: Test pre-releases in a controlled environment to prevent connecting with incompatible versions on IOHK network and also have a stable environment to learn/study.
- Remember: To avoid spamming logs of nodes of other network (invalid block0), please ensure to not re-use IP-port combination between different networks
- Also Remember: Before starting node, ensure your storage folder is empty
- Cap: Pools intending to run their stake pool have been distributed 1000000000 Test Lovelaces (RC4), would be great if we use it as a cap.
- For genesis hash and faucet funds request, we expect you to know where the secret hideout is.
- For helper scripts, these are either copies - or small modifications of IOHK provided helper scripts to keep them compatible with versions here.

## v0.8.0rc4

### Trusted Peers
```
  trusted_peers:
    #rdlrt
    - address: /ip4/139.99.221.149/tcp/4003
      id: 3799c23842a0fbfa4acc29dda595dd03a14fa48cf38012ff
    #mark-stopka
     - address: /ip4/82.209.54.77/tcp/3000
       id: d0c0e9e18e585742ea017fb12285b276d62a74721c526523
    #ocg
    #- address: /ip4/167.71.144.137/tcp/9779
    #  id: 730758be44ce4faa90baae1505ae483f3d2a5dac26590237
    #markus
    - address: /ip4/185.161.193.61/tcp/9031
      id: ada4cafebabecafebabecafebabecafebabecafebabe4ada
    rcmorano
    - address: /ip4/51.15.64.122/tcp/9299
      id: ada75dfb9b60d10bd46bcbaa1eaeb29662386c367265e9c7
    #psychomb
    - address: /ip4/51.91.96.237/tcp/3377
       id: 1eaf62ec280f266717b47ca53a80c1bae0e49589ade6654b

```
