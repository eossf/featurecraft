# featurecraft

Test of Qwen3 LLM reasonning model

## Kestra Installation with terraform

See prompt.txt

It's a docker compose application.

## Run manually Kestra

### Run with docker

```
docker run --pull=always --rm -it -p 8080:8080 --user=root \
 -v $PWD/application.yaml:/etc/config/application.yaml \
 -v /var/run/docker.sock:/var/run/docker.sock \
 -v /tmp:/tmp kestra/kestra:latest server standalone --config /etc/config/application.yaml
 ```

## MISC

The infrastructure is hosted by Vultr

### VULTR

[api vultr](https://www.vultr.com/api/)

#### Examples of curl list of items 

```bash
curl -k "https://api.vultr.com/v2/regions"   -X GET   -H "Authorization: Bearer ${VULTR_API_KEY}"
curl -k "https://api.vultr.com/v2/instances"   -X GET   -H "Authorization: Bearer ${VULTR_API_KEY}"
curl -k "https://api.vultr.com/v2/os"   -X GET   -H "Authorization: Bearer ${VULTR_API_KEY}"
```
