#! /bin/bash

: '
=== HOW TO RUN ===

For running this installer, in the application "Terminal" type:
"/pathToThisFolder/install-uninstall.sh"

For a list of programs installed like this type:
ls /etc/install-uninstall


=== PURPOSE ===

This installer is mostly for trying out the software
If you end liking it, ask someone how to package it

If your system includes the app "pacman", you can get those packages at:
https://gitlab.com/es20490446e/express-repository/-/wikis/home


=== LEGALESE ===

Installer by Alberto Salvia Novella (es20490446e.wordpress.com)
Under the latest GNU Affero License
https://gitlab.com/es20490446e/install-uninstall.sh
'


# For testing the installer:
update="true"
simulate="false"
clean="false"

# Others:
here="$(realpath "$(dirname "${0}")")"
program="$(cd "${here}"; echo "${PWD##*/}")"
in="${here}/root"
etc="/etc/install-uninstall"
lists="${etc}/${program}"
fileList="${lists}/files"
dirList="${lists}/dirs"


mainFuntion () {
	if [[ ! -d "${out}${lists}" ]]; then
		checkDependencies
		builds
		setIn
		pre_install
		installs
		post_install
	else
		pre_remove
		uninstalls
		post_remove
	fi
}


builds () {
	if [[ -f "${here}/build.sh" ]] && [[ ! -d "${here}/_ROOT" ]] && [[ ! -d "${here}/root" ]]; then
		bash "${here}/build.sh"
		
		if [[ -d "${here}/_ROOT" ]]; then
			local root="${here}/_ROOT"
		elif [[ -d "${here}/root" ]]; then
			local root="${here}/root"
		else
			echo "build.sh hasn't created anything into the dir \"_ROOT\"" >&2
			exit 1
		fi
		
		chown --recursive "$(logname)" "${root}"
	fi
}


checkDependencies () {
	local list="${here}/info/dependencies.txt"

	if [[ -f "${list}" ]]; then
		local lines; readarray -t lines < <(cat "${list}")
		local missing=()

		for line in "${lines[@]}"; do
			local name; name="$(echo "${line}" | cut --delimiter='"' --fields=2)"
			local path; path="$(echo "${line}" | cut --delimiter='"' --fields=4)"
			local web; web="$(echo "${line}" | cut --delimiter='"' --fields=6)"

			if [[ -n "${web}" ]]; then
				local web="(${web})"
			fi

			if [[ ! -f "${path}" ]]; then
				local missing+=("${name}  ${web}")
			fi
		done

		if [[ "${#missing[@]}" -gt 0 ]]; then
			echo "Missing required software:" >&2
			echo >&2
			printf '%s\n' "${missing[@]}" >&2
			echo >&2
			echo "Get those installed first"
			echo "and run this installer again"
			exit 1
		fi
	fi
}


checkPermissions () {
	if [[ "${simulate}" == "false" ]] && [[ "$(id -u)" -ne 0 ]]; then
		sudo "${0}"
		exit ${?}
	fi
}


cleanUp () {
	if [[ "${clean}" == "true" ]]; then
		if [[ -n "${out}" ]] && [[ -d "${out}" ]]; then
			rm --recursive "${out}"
		fi
	elif [[ "${clean}" != "false" ]]; then
		invalidVariable "clean"
	fi
}


createLists () {
	if [[ ! -d "${out}${lists}" ]]; then
		mkdir --parents "${out}${lists}"
	fi

	echo "${fileList}" > "${out}${fileList}"
	# shellcheck disable=SC2129
	echo "${dirList}" >> "${out}${fileList}"
	find "${in}" -not -type d -printf "/%P\n" >> "${out}${fileList}"
	
	find "${in}" -type d \( ! -wholename "${in}" \) -printf "/%P\n" | tac > "${out}${dirList}"
	# shellcheck disable=SC2129
	echo "${lists}" >> "${out}${dirList}"
	echo "${etc}" >> "${out}${dirList}"
	echo "/etc" >> "${out}${dirList}"
}


dirIsEmpty () {
	local dir="${1}"

	if [[ -z "$(find "${dir}" -maxdepth 1 \( ! -wholename "${dir}" \) | head -n1)" ]]; then
		true
	else
		false
	fi
}


fileMime () {
	local file="${1}"

	file --brief --mime "${file}" |
	cut --delimiter=';' --fields=1
}


fileParents () {
	local file="${1}"

	echo "${file}" |
	rev |
	cut --delimiter='/' --fields=2- |
	rev
}


installs () {
	createLists	
	rsync --archive --no-owner --no-group "${in}/" "${out}/"
	echo "installed"
}


invalidVariable () {
	local variable="${1}"

	echo "The variable \"${variable}\" has an invalid value" >&2
	echo "It can either be \"true\" or \"false\""
	exit 1
}


post_install () {
	:
}


post_remove () {
	:
}


prepareEnvironment () {
	set -e
	cd "${here}"
	updateInstaller
	setOut
	checkPermissions
	trap "" INT QUIT TERM EXIT
	cleanUp
	sourceRecipes
}


pre_install () {
	:
}


pre_remove () {
	:
}


setIn () {
	if [[ -d "${here}/root" ]]; then
		in="${here}/root"
	elif [[ -d "${here}/_ROOT" ]]; then
		in="${here}/_ROOT"
	else
		echo "No root or _ROOT folder" >&2
		echo "Either put the filesystem to install into \"root\""
		echo "or create a \"build.sh\" that compiles the filesystem into \"_ROOT\""
		exit 1
	fi
}


setOut () {
	if [[ "${simulate}" == "false" ]]; then
		out=""
	elif [[ "${simulate}" == "true" ]]; then
		out="${here}/simulated install"
	else
		invalidVariable "simulate"
	fi
}


sourceRecipes () {
	# shellcheck disable=SC1091
	if [[ -f "${here}/recipes.sh" ]]; then
		source "recipes.sh"
	fi
}


uninstalls () {
	readarray -t files < <(cat "${out}${fileList}")
	readarray -t dirss < <(cat "${out}${dirList}")

	for file in "${files[@]}"; do
		rm --force "${out}${file}"
	done

	for dir in "${dirss[@]}"; do	
		if [[ -d "${out}${dir}" ]] && dirIsEmpty "${out}${dir}"; then
			rm --recursive "${out}${dir}"
		fi
	done

	if [[ -n "${out}" ]] && dirIsEmpty "${out}"; then
		rm --recursive "${out}"
	fi

	echo "uninstalled"
}


updateInstaller () {
	if [[ "${update}" == "true" ]]; then
		local remote; remote="$(curl --silent "https://gitlab.com/es20490446e/install-uninstall.sh/-/raw/master/install-uninstall.sh")"
		local local; local="$(cat "${0}")"

		if [[ -z "${remote}" ]]; then
			if [[ -z "$(curl --silent google.com)" ]]; then
				echo "No Internet, which is required" >&2
			else
				echo "Cannot get the updated installer" >&2
				echo "Ask developers to fix this"
			fi

			exit 1
		fi

		if [[ "${remote}" != "${local}" ]]; then
			echo "${remote}" > "${0}"
			sudo "${0}"
			exit ${?}
		fi
	elif [[ "${update}" != "false" ]]; then
		invalidVariable "update"
	fi
}


prepareEnvironment "${@}"
mainFuntion
