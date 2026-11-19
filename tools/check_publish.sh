#!/usr/bin/env sh
# Varredura antes de publicar (repositório público). Olha só o que o git vai versionar:
# arquivos rastreados + novos não ignorados. Sai com 1 se achar algo para revisar.
#   sh tools/check_publish.sh
cd "$(dirname "$0")/.." || exit 2
files=$( (git ls-files; git ls-files --others --exclude-standard) | sort -u)
problems=0

report() {
	echo "$1"
	echo "$2" | sed 's/^/    /'
	problems=1
}

# Arquivos que nunca devem entrar (o .gitignore já cobre; isto pega exceções forçadas).
hits=$(echo "$files" | grep -iE '(^|/)(export_credentials.cfg|\.env(\..*)?)$|\.(exe|pck|apk|aab|keystore|jks|p12|pfx|pem|key)$|(^|/)\.godot/|(^|/)build/')
[ -n "$hits" ] && report "Arquivos que não podem ser publicados:" "$hits"

# Presets de exportação: nenhuma senha, keystore ou chave de criptografia preenchida.
hits=$(grep -nE '(password|keystore/[a-z_]+|encryption_key|script_encryption_key)="[^"]+"' export_presets.cfg 2>/dev/null)
[ -n "$hits" ] && report "Segredo no export_presets.cfg:" "$hits"

# Caminhos da máquina, pastas de usuário e e-mails.
hits=$(echo "$files" | tr '\n' '\0' | xargs -0 grep -IlE '[A-Za-z]:[\\/](Users|Projetos)[\\/]|/home/[a-z]+/|/Users/[A-Za-z]+/|AppData[\\/]|[A-Za-z0-9._%+-]+@(gmail|hotmail|outlook|yahoo)\.' 2>/dev/null)
[ -n "$hits" ] && report "Caminhos locais ou e-mails:" "$hits"

# Cara de segredo.
hits=$(echo "$files" | tr '\n' '\0' | xargs -0 grep -IlE 'BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY|ghp_[A-Za-z0-9]{20}|sk-[A-Za-z0-9]{20}|AKIA[0-9A-Z]{16}|(api[_-]?key|password|senha)[[:space:]]*[:=][[:space:]]*["'"'"'][^"'"'"']+' 2>/dev/null)
[ -n "$hits" ] && report "Possíveis segredos:" "$hits"

# Arquivos grandes (> 10 MB): conferir se precisam mesmo ir.
hits=$(echo "$files" | tr '\n' '\0' | xargs -0 find 2>/dev/null -maxdepth 0 -type f -size +10M)
[ -n "$hits" ] && report "Arquivos com mais de 10 MB:" "$hits"

# Assets de terceiros: cada pacote da Kenney tem a licença em assets/kenney/licenses/ e o áudio
# tem a sua em assets/audio; tudo também está no CREDITS.md.
[ -d assets/kenney/licenses ] && ls assets/kenney/licenses | grep -q . || report "Licenças da Kenney ausentes:" "assets/kenney/licenses/"
for dir in assets/kenney/*/; do
	[ "$dir" = "assets/kenney/licenses/" ] && continue
	name=$(basename "$dir")
	grep -qi "assets/kenney/$name" CREDITS.md || report "Pacote da Kenney sem crédito no CREDITS.md:" "$dir"
done
for f in assets/audio/sfx/* assets/audio/music/*; do
	case "$f" in *.import) continue ;; esac
	base=$(basename "$f" | sed 's/\.[^.]*$//')
	[ -n "$base" ] || continue
	grep -qw "$base" CREDITS.md || report "Som sem crédito no CREDITS.md:" "$f"
done

if [ "$problems" -eq 0 ]; then
	echo "Nada encontrado. Revise ainda o checklist manual do README."
fi
exit "$problems"
