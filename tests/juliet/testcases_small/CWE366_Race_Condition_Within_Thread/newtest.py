import os
import re
import subprocess


def check_path(filepath):
	files = os.listdir(filepath)
	v_files = [] # Valid files
	#iv_files = [] # Invalid files
	dirs = [] # Directories
	for f in files:
		if re.search('^CWE', f) != None and re.search('\.c$', f) != None and re.search('w32', f) == None: v_files.append(f)
		elif os.path.isdir(f): dirs.append(f)
		#else: iv_files.append(f)
	return v_files, dirs # v_files, iv_files, dirs
	


def run_function(filepath, filename, mode):
	func = filename.split('.')[0] + mode # '_good'
	cmd = '../../../../goblint ' + filepath + ' -I "../../testcasesupport" --sets "mainfun[+]" ' + func
	process = subprocess.run(cmd, shell=True, check=True, stdout=subprocess.PIPE, universal_newlines=True)
	return process.stdout
	


def goblint_files(testcases, filepath, html_table):
	# Create the table's column headers
	html_table += '\n<p id="' + filepath + '">Folder: ' + filepath + '</p>\n'
	html_table += "<table border=1>\n"
	header = ['Testcase', 'Good', 'Bad']
	html_table += "  <tr>\n"
	for column in header:
		html_table += "    <th>{0}</th>\n".format(column.strip())
	html_table += "  </tr>\n"
	# Going through valid testcase files
	testcases.sort()	
	for t in testcases:
		f_path = filepath + '/' + t
		output_good = run_function(f_path, t, '_good') # 'good' function
		output_bad = run_function(f_path, t, '_bad') # 'bad' function
		
		v_good = '-' # Vulnerabilities in 'good', initial value
		v_bad = '-' # Vulnerabilities in 'bad', initial value
		
		if re.search('-------------------', output_good) != None:
			v_good = 'X'
		if re.search('-------------------', output_bad) != None:
			v_bad = 'X'

		result = [t, v_good, v_bad]
		
		html_table += "  <tr>\n"
		for column in result:
			html_table += "    <td>{0}</td>\n".format(column.strip())
		html_table += "</tr>\n"
	html_table += "</table>\n"
	html_table += '<br><a href="#top">Go to top</a><hr><br>\n'
	return html_table
	

path = '.'
#table = '<p><big><strong>RESULTS</strong></big></p>'
table = '<p style="font-size:30px">RESULTS</p>'


#files = os.listdir(path)

# 1. vaatab kas on kaustas .c testcasesid, hakkab neid kohe tegema kui on
# 2. vaatab kas kaustas on foldereid, kui on hakkab neist jarjest labikaima

# pathi ehitamine

# table ehitamine

# input argument filepath



# In the running dir
current_dir = path
valid_files, directories = check_path(current_dir)
if len(valid_files) > 0:	
	table = goblint_files(valid_files, current_dir, table)
	
	

print(len(valid_files))	
print(len(directories))
	
# Going through the main CWE directories if present
for d in directories:
	current_dir = path + '/' + d
	valid_files, sub_directories = check_path(current_dir)
	if len(valid_files) > 0:
		table = goblint_files(valid_files, current_dir, table)
	# When the main CWE dir is split into sub-directories (s01, s02, ...)
	for s in sub_directories:
		current_subdir = current_dir + '/' + s
		valid_files, nodir = check_path(current_subdir)
		if len(valid_files) > 0:
			table = goblint_files(valid_files, current_subdir, table)
		
		

with open('table_2.html', 'w', encoding='utf-8') as file:
	file.write(table)	

'''
	
print(len(valid_files))
print(len(invalid_files))
print(len(directories))


while len(directories) >= 0:
	current_dir = path
	if len(valid_files) > 0:
		goblint_files(valid_files, current_dir)
	
	if len(directories) > 0:
		path = paht + directories.pop(0)
'''		

	

'''
if len(valid_files) > 0:
	for f in valid_files:
		_path = path + '/' + folder + '/' + t
		output_good = run_function(f_path, t, '_good') # 'good' function
		#output_bad = run_function(f_path, t, '_bad') # 'bad' function
		
if len(directories) > 0:
	for d in directories:
		if re.search('^CWE', f) != None and re.search('\.c$', f) != None and re.search('w32', f) == None: valid_files.append(f)
		elif os.path.isdir(f): directories.append(f)
		else: invalid_files.append(f)
'''		



