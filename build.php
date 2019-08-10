<?php declare(strict_types=1);

$mode = 'tight';

$lists = [];

foreach (scandir('/data/lists') as $f) {
    if (pathinfo($f, PATHINFO_EXTENSION) === 'yaml') {
        $parsed = yaml_parse_file("/data/lists/$f");
        $lists = array_merge_recursive($lists, $parsed);
    }
}

# begin parsing rulesets unless we are in off mode
if ($mode !== 'off') {
    if ($mode === 'tight') {
        foreach (($lists['whitelist'] ?? []) as $row) {
            if (trim($row)) {
                $rules[] = "server=/.$row/127.0.0.1#53";
                $rules[] = "server=/.$row/::1#53";
            }
        }
    }
    foreach (($lists['blacklist'] ?? []) as $row) {
        if (trim($row)) {
            $rules[] = "address=/.$row/0.0.0.0";
            $rules[] = "address=/.$row/::";
        }
    }
}

# inject raw dnsmasq config statements
foreach (($lists['raw'] ?? []) as $row) {
    $rules[] = $row;
}

# add the blackhole for all non-matching
if ($mode === 'tight') {
    $rules[] = "address=/#/0.0.0.0";
    $rules[] = "address=/#/::";
}

file_put_contents("/data/confs/rules", implode("\r\n", $rules));