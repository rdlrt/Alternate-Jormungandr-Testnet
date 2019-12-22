# Important:
- Intention: Test pre-releases in a controlled environment to prevent connecting with incompatible versions on IOHK network and also have a stable environment to learn/study.
- Remember: To avoid spamming logs of nodes of other network (invalid block0), please ensure to not re-use IP-port combination between different networks
- Also Remember: Before starting node, ensure your storage folder is empty
- Cap: Pools intending to run their stake pool have been distributed 1000000000 Test Lovelaces, would be great if we use it as a cap.
- For genesis hash and faucet funds request, we expect you to know where the secret hideout is.
- For helper scripts, these are either copies - or small modifications of IOHK provided helper scripts to keep them compatible with versions here.

## v0.8.5a3

### Trusted Peers
```
  trusted_peers:
    #rdlrt
    - address: /ip4/139.99.221.149/tcp/4007
      id: 0add359010d13fc0e9d403c822887638969276aaedccd1f4
    #rcmorano
    - address: /ip4/51.15.64.122/tcp/38299
      id: be6440b4953a7f862551a3d3a3e3ada55214317c57fdeb24
```
