### NAME  
**hasher** - renames files in a directory by their hash

### SYNOPSIS  
**hasher** <u>directory</u> [<u>conflicts</u>]

### DESCRIPTION
The **hasher** tool recursively renames all files in a directory according to their MD5 hash.

### OPTIONS
<u>directory</u>  
Parent directory for files to be searched and renamed.

[<u>conflicts</u>]  
The file that any file that had a conflict when attempting to rename it will be written to.
> [!NOTE]  
> When a conflict file is provided, **hasher** will run in parallel and not stop when there is a conflict.

### EXIT STATUS  
**hasher** will return 1 if there are any errors.
Otherwise, **hasher** exits with status code 0.

### AUTHORS  
Harry N
