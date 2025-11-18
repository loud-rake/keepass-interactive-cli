#!/usr/bin/env bash
set -x

# Defaults database to ~/Passwords.kdbx
if [[ -z $1 ]]; then
	# '~/Passwords.kdbx' does not work for some reason, but this does.
	database="$HOME/Passwords.kdbx"
else
	database="$1"
fi

# Check that database exists.
if [[ ! -e "$database" ]]; then
	echo "$database doesn't exist."
	exit 1
fi

# Grab key credentials
echo -n "Enter database's password:"
read -s password

# Verify the credentials are gtg, print keepassxc's error message if not.
if ! $(keepassxc-cli ls "$database" <<< "$password" &> /dev/null); then
	keepassxc-cli ls "$database" <<< "$password"
	exit 1
fi

# Use fuzzy search to grab a selection from the database
get_entry() {
	read -d '\n' -a database_entries <<< \
		$(keepassxc-cli ls -R "$database" <<< "$password" \
		# The "Enter password to unlock" line is in stderr.
		2> >(grep -v "Enter password to unlock"))
	while true; do
		selection=$(printf '%s\n' "${database_entries[@]}" | fzf)
		if [[ -z $selection ]]; then
			echo 'You have not selected an entry!'
			# Leave the user time to read the message
			# (or close the script)
			sleep 1.5
			continue
		else
			break
		fi
	done
		
}

show_entry() {
	keepassxc-cli show "$database" "$selection" <<< "$password" \
		2> >(grep -v "Enter password to unlock")
}

copy_entry_password() {
	keepassxc-cli clip "$database" "$selection" <<< "$password" \
		2> >(grep -v "Enter password to unlock")
}

copy_entry_totp () {
	keepassxc-cli clip --totp "$database" "$selection" <<< "$password" \
		2> >(grep -v "Enter password to unlock")
}

add_entry() {
	keepassxc-cli add "$generate" --username "$entry_username" \
		--url "$entry_url" --notes "$entry_notes" "$database" \
		"$entry_title" <<< "$password" \
		> >(grep -v "Enter password to unlock") && echo "Done."
}

edit_entry() {
	keepassxc-cli edit "$generate" --username "$entry_username" \
		--url "$entry_url" --notes "$entry_notes" \
		--title "$entry_title" "$database" "$selection" <<< "$password" \
		> >(grep -v "Enter password to unlock") && echo "Done."
}

add_edit_entry() {
	case "$action" in
		add)
			while true; do
				echo "Entry's title:"
				read entry_title
				if [[ -z "$entry_title" ]]; then
					echo "You have to provide a title."
					continue
				else
					break
				fi
			done
			;;
		edit)
			while true; do
				echo "Entry's title (Enter to not change it):"
				read entry_title
				if [[ -z "$entry_title" ]]; then
					entry_title="$selection"
					break
				else
					break
				fi
			done
			;;
	esac

	echo "Entry's username (Enter to leave empty):"
	read entry_username

	echo "Entry's url (Enter to leave empty):"
	read entry_url

	echo "Entry's notes (Enter to leave empty):"
	read entry_notes

	echo "Do you want to generate a password? (Y/n):"
	read input

	while true; do
		case "$input" in
			y|Y|"")
				generate="-g"
				break
				;;
			n|N)
				generate="-p"
				break
				;;
			*)
				echo "Imvalid input!"
				continue
				;;
		esac
	done
}

print_menu() {
	cat <<- EOF
	Menu:
	1) Copy entry password
	2) Show entry details
	3) Copy TOTP
	4) Add entry
	5) Edit entry
	0) Exit
	EOF
}

# Enter interactive session
while true; do
	print_menu
	read input
	case $input in
		1)
			get_entry
			show_entry
			copy_entry_password
			;;
		2)
			get_entry
			show_entry
			;;
		3)
			get_entry
			show_entry
			copy_entry_totp
			;;
		4)
			get_entry

			# Defines the behavior of the first
			# prompt of add_edit_entry
			action=add
			add_edit_entry
			add_entry
			show_entry
			;;
		5)
			get_entry
			action=edit
			add_edit_entry
			edit_entry
			show_entry
			;;
		0)
			exit 0
			;;
		*)
			echo "Invalid input!"
			;;
	esac
done
