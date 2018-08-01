<?php

class MoveIncomingClientData
{
    public $client_incoming = "";
    public $extension_repetitive_files = ".DUP";
    public $sftp_folder = "/encrypted/sftp/";
    public $sftp_automated_backup = "/encrypted/sftp_automated_backup/[mapped_client_name]/incoming/";
    public $gateway_incoming = "/encrypted/rmedi/incoming/[mapped_client_name]/";

    public function __construct(){
        $this->client_incoming = $this->sftp_folder . "[mapped_client_name]/incoming/";
        $this->run();
    }

    public function run() {
        if ( is_dir($this->sftp_folder) ) {
            // /encrypted/sftp_clients/
            foreach (new DirectoryIterator($this->sftp_folder) as $clientFolder) {
                // If this directory is like these: . or .. we need to skip it
                if($clientFolder->isDot()) continue;

                // Clients directories
                elseif($clientFolder->isDir()) {
                    $current_client = $clientFolder->getBasename();
                    $current_client_incoming = str_replace("[mapped_client_name]", $current_client, $this->client_incoming);

                    // /encrypted/sftp/[mapped_client_name]/incoming/
                    if ( is_dir($current_client_incoming) ) {
	                    // /encrypted/sftp/[mapped_client_name]/incoming/claims, remits, payments, etc
	                    foreach (new DirectoryIterator($current_client_incoming) as $typeOfFilesFolder) {
		                    // If this directory is like these: . or .. we need to skip it
		                    if ($typeOfFilesFolder->isDot()) continue;

		                    // Folders: Claims, Remits, Payments, etc
		                    elseif ($typeOfFilesFolder->isDir()) {
			                    $current_type_file_folder = $typeOfFilesFolder->getBasename();
			                    $current_gateway_client_incoming = str_replace("[mapped_client_name]", $current_client, $this->gateway_incoming) . $current_type_file_folder;
			                    $current_sftp_backup_client_incoming = str_replace("[mapped_client_name]", $current_client, $this->sftp_automated_backup) . $current_type_file_folder;

			                    // Claims, Remits, Payments, etc folders. If these kind of folders doesn't exist on directory destiny, we don't need to move nothing of this folder
			                    if ( is_dir($current_gateway_client_incoming) || is_dir($current_sftp_backup_client_incoming) ) {
				                    // Add all the files paths recursively
				                    $files_paths_array = array();
				                    $this->getAllFilePaths($current_gateway_client_incoming, $files_paths_array);
				                    $this->getAllFilePaths($current_sftp_backup_client_incoming, $files_paths_array);

				                    if ( !empty($files_paths_array) ) {
					                    foreach( new RecursiveIteratorIterator(new RecursiveDirectoryIterator($typeOfFilesFolder->getPathname(), RecursiveDirectoryIterator::SKIP_DOTS)) as $file) {
						                    if ( $file->isFile() ) {
							                    $filename = $file->getFilename();
							                    $length_file = strlen($filename);
							                    // Ignore if this file is a file part extension
							                    if ( substr($filename, $length_file - 9, $length_file) != ".filepart" ) {
								                    $this->findRepeatedFileName($file, $files_paths_array);
							                    } else {
							                        echo "This filepart file was ignored: " . $filename . "\n";
							                    }
						                    }
					                    }
				                    }
			                    }
		                    }
	                    }
                    }
                }
            }
        }
    }

    // This is to get all the files recursively and add them to array by reference
    function getAllFilePaths($path, array &$files_paths_array) {
        if ( is_dir($path) ) {
            foreach( new RecursiveIteratorIterator(new RecursiveDirectoryIterator($path, RecursiveDirectoryIterator::SKIP_DOTS)) as $file) {
                if ( $file->isFile() ) {
                    $files_paths_array[$file->getFilename()][] = $file->getPathname();
                }
            }
        }
        return $files_paths_array;
    }

    // This is only to check if the file name is repeat it in gateway or sftp backup
    function findRepeatedFileName($file_to_compare, $files_paths_array) {
        $dup_number = 0;
        $files_with_same_name = array();
        $pattern = "/^" . preg_quote($file_to_compare->getFilename()) . "(?:" . preg_quote($this->extension_repetitive_files) . "(?P<num_ext_rep_fls>\d+))?$/";
        // Only compare if we have the same kind of folders in gateway incoming to compare "apples" vs "apples" (claims, remits, etc)

        // Gateway / SFTP_Backup
        foreach ( $files_paths_array as $filename => $filepaths ) {
            // Check if we have the same name of file
            if ( preg_match($pattern, $filename, $matches) ) {

            	// Assign the files with the same name
            	foreach ($filepaths as $fp) {
		            $files_with_same_name[] = $fp;
	            }

                // This is a kind of repetitive file extension like this: edi_file.DUP1
                if ( isset($matches['num_ext_rep_fls']) ) {
                    $dup_number = (int)$matches['num_ext_rep_fls'] > $dup_number? (int)$matches['num_ext_rep_fls'] : $dup_number ;
                }
            }
        }

        if ( ! empty($files_with_same_name) ) {
            $this->fixRepeatedFileContent($file_to_compare->getPathname(), $files_with_same_name, $dup_number);
        } else {
	        echo "There is no conflict with the name or content for this file: " . $file_to_compare . "\n";
        }

        return true;
    }

    // This is to fix the problem when we found the repetitive name. First we check if we have the same content, if not, we need to change the name of the file for .DUP extension
    function fixRepeatedFileContent($new_file, array $files_with_same_name, $dup_number = 0) {
	    echo "Check this file: " . $new_file . "\n";
	    $dup_number = $dup_number == 0 ? 1 : $dup_number + 1;

	    foreach ( $files_with_same_name as $file_to_compare ) {

            $command = "cmp --silent " . escapeshellarg($new_file). " " . escapeshellarg($file_to_compare) ." || echo 'Files are Different'";
            $result = exec($command);

	        if ( $result !== "Files are Different" ) {
            	echo "Repeated file content\n";
                // Change the date of the new file
	            echo "Update the date for this file: " . $file_to_compare . "\n";
	            touch($file_to_compare, filemtime($new_file));
                // Delete it, because there are duplicated files
	            echo "Delete repetitive file: " . $new_file . "\n";
	            unlink($new_file);

	            // If we found a repetitive file, we need to change the date, delete it and then we don't need to do nothing for that file
                return true;
            }
        }

	    echo "Rename repetitive file name to: " . $new_file . $this->extension_repetitive_files . $dup_number . "\n";
        rename($new_file, $new_file . $this->extension_repetitive_files . $dup_number);
        return true;
    }
}

$process = new MoveIncomingClientData();