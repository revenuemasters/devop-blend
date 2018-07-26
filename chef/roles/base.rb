name 'base'
description 'Base role for all instances'
run_list 'recipe[revenuemasters]'
override_attributes(
  'logrotate' => {
    'package' => {
      'action' => :nothing # Prevent the logrotate cookbook from touching the logrotate package.
    }
  }
)
