function backup --description 'Back up ~/stuff and machine state to R2 now (kw-backup.service)'
    journalctl --user -u kw-backup -f -n 0 -o cat &
    set -l follow $last_pid
    systemctl --user start kw-backup.service
    set -l rc $status
    kill $follow
    if test $rc -eq 0
        echo "Backup done."
    else
        echo "Backup failed ($rc): journalctl --user -u kw-backup -n 50"
    end
    return $rc
end
