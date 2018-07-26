name 'worker'
description 'worker role'
run_list 'role[base]', 'recipe[revenuemasters::app]', 'recipe[revenuemasters::worker]', 'recipe[revenuemasters::archive_to_s3]'
