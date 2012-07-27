<?php

/*
Sample atoum configuration file to have code coverage in html format.
Do "php path/to/test/file -c path/to/this/file" or "php path/to/atoum/scripts/runner.php -c path/to/this/file -f path/to/test/file" to use it.
*/

use \mageekguy\atoum;

$stdOutWriter = new atoum\writers\std\out();

/*
Please replace in next line /path/to/destination/directory by your destination directory path for html files.
*/
$coverageField = new atoum\report\fields\runner\coverage\html('atoum', __DIR__.'/output');

/*
Please replace in next line http://url/of/web/site by the root url of your code coverage web site.
*/
$coverageField->setRootUrl('http://localhost/workspace/gw2cbackend/tests/output');

$cliReport = new atoum\reports\realtime\cli();
$cliReport
	->addWriter($stdOutWriter)
	->addField($coverageField, array(atoum\runner::runStop))
;

$runner->addReport($cliReport);
