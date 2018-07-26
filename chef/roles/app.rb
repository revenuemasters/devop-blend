name 'app'
description 'app role'
run_list 'role[base]', 'recipe[revenuemasters::app]', 'recipe[revenuemasters::monitor_root]', 'recipe[revenuemasters::monitor_encrypted]', 'recipe[revenuemasters::archive_to_s3]'
