# Important:
- Intention: Test pre-releases in a controlled environment to prevent connecting with incompatible versions on IOHK network and also have a stable environment to learn/study.
- Remember: To avoid spamming logs of nodes of other network (invalid block0), please ensure to not re-use IP-port combination between different networks
- Also Remember: Before starting node, ensure your storage folder is empty
- Cap: Pools intending to run their stake pool have been distributed 1000000000 Test Lovelaces (RC4), would be great if we use it as a cap.
- For genesis hash and faucet funds request, we expect you to know where the secret hideout is.
- For helper scripts, these are either copies - or small modifications of IOHK provided helper scripts to keep them compatible with versions here.

## v0.8.0rc5

### Trusted Peers
```
  trusted_peers:
    #rdlrt
    - address: /ip4/139.99.221.149/tcp/4004
      id: 82d6c6a47f55b929d97718215acd7f39257692d7b2ecdc0f
    #markus
    - address: /ip4/185.161.193.61/tcp/9030
      id: ada4cafebabecafebabecafebabecafebabecafebabe4ada
```
