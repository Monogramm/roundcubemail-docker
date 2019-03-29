#!/bin/bash
set -eu

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

min_version='1.3'


# version_greater_or_equal A B returns whether A >= B
function version_greater_or_equal() {
	[[ "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1" || "$1" == "$2" ]];
}

latest="$(curl -sS https://roundcube.net/VERSION.txt)"

latests=( $latest 1.4-rc1 )

# FIXME Cannot use GitHub tags because older versions use `vX.Y.Z` instead of `X.Y.Z`
# Will be better if GitHub implements sorting by date...
#$( curl -fsSL 'https://api.github.com/repos/roundcube/roundcubemail/tags' |tac|tac| \
#	grep -oE '[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+' | \
#	sort -urV )

#set -x

echo "update docker images"
travisEnv=
for latest in "${latests[@]}"; do
	version=$(echo "$latest" | cut -d. -f1-2)

	# Only add versions >= "$min_version"
	if version_greater_or_equal "$version" "$min_version"; then

		for variant in apache fpm fpm-alpine; do
			dir="$version/$variant"
            if [ -d "$dir" ]; then
                rm -rf "$dir"
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

			travisEnv+='\n  - VERSION='"$latest"' VARIANT='"$variant"
		done

	fi

done


travis="$(awk -v 'RS=\n\n' '$1 == "env:" { $0 = "env:'"$travisEnv"'" } { printf "%s%s", $0, RS }' .travis.yml)"
echo "$travis" > .travis.yml
