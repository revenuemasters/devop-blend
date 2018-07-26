name 'sftp'
description 'sFTP role'
run_list 'role[base]', 'recipe[openssh]', 'recipe[revenuemasters::edi]', 'recipe[revenuemasters::edi_ui]', 'recipe[revenuemasters::edi_monitor]', 'recipe[revenuemasters::sftp]', 'recipe[revenuemasters::monitor_root]', 'recipe[revenuemasters::monitor_encrypted]', 'recipe[revenuemasters::archive_to_s3]'
