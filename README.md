# waf

ModSecurity Nginx основанный на докер образе [owasp/modsecurity-crs:nginx-alpine](https://hub.docker.com/r/owasp/modsecurity-crs/)

## Как запустить:

```bash
bash modsec_up.sh [port] [address] [absolute path to config folder]
```

### Как добавлять правило:

 - Добавьте правило в директорию, которую передаете в скрипт
 - Перезагрузите сервер
