#!/bin/bash
set -eu

declare -A compose=(
	[apache]='apache'
	[fpm]='fpm'
	[fpm-alpine]='fpm'
)

declare -A cmd=(
	[apache]='apache2-foreground'
	[fpm]='php-fpm'
	[fpm-alpine]='php-fpm'
)

declare -A extras=(
	[apache]='\n# enable mod_rewrite\nRUN a2enmod rewrite'
	[fpm]=''
	[fpm-alpine]=''
)

declare -A base=(
	[apache]='debian'
	[fpm]='debian'
	[fpm-alpine]='alpine'
)

variants=(
	apache
	fpm
	fpm-alpine
)

min_version='1.3'


# version_greater_or_equal A B returns whether A >= B
function version_greater_or_equal() {
	[[ "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1" || "$1" == "$2" ]];
}

latests=( $( git ls-remote --tags https://github.com/roundcube/roundcubemail.git  | cut -d/ -f3 \
		| grep -P -- '^[\d\.]+(-rc\d+)?$' \
		| sort -rV ) )

#set -x

# Remove existing images
echo "reset docker images"
rm -rf ./images/
mkdir -p ./images/

echo "update docker images"
travisEnv=
for latest in "${latests[@]}"; do
	version=$(echo "$latest" | cut -d. -f1-2)

	echo "checking $latest ($version)..."
	# Only add versions >= "$min_version"
	if version_greater_or_equal "$version" "$min_version"; then

		for variant in "${variants[@]}"; do
			dir="images/$version/$variant"
            if [ -d "$dir" ]; then
                continue
            fi

            echo "generating $latest [$version] $variant"
			mkdir -p "$dir"

			template="Dockerfile-${base[$variant]}.template"
			cp $template "$dir/Dockerfile"
			cp docker-entrypoint.sh "$dir/docker-entrypoint.sh"
			cp php.ini "$dir/php.ini"
			sed -E -i'' -e '
				s/%%VARIANT%%/'"$variant"'/;
				s/%%VARIANT_EXTRAS%%/'"${extras[$variant]}"'/;
				s/%%VERSION%%/'"$latest"'/;
				s/%%CMD%%/'"${cmd[$variant]}"'/;
			' "$dir/Dockerfile"

			cp ".dockerignore" "$dir/.dockerignore"
			cp "docker-compose_${compose[$variant]}.yml" "$dir/docker-compose.yml"

			travisEnv+='\n  - VERSION='"$version"' VARIANT='"$variant"
		done

	else
		# Stop when we reached minium version
		break
	fi

done


travis="$(awk -v 'RS=\n\n' '$1 == "env:" { $0 = "env:'"$travisEnv"'" } { printf "%s%s", $0, RS }' .travis.yml)"
echo "$travis" > .travis.yml

echo "update finished"
