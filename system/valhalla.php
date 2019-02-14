<?php

$command = $argv[1] ?? null;
$dir = __DIR__;
$yaml = yaml_parse_file(__DIR__ . '/../config.yaml');

switch ($command) {
    case '3p':
    case '3':
        `curl -fsSL https://raw.githubusercontent.com/notracking/hosts-blocklists/master/domains.txt > /etc/dnsmasq.d/notracking`;

        `curl -fsSL https://raw.githubusercontent.com/notracking/hosts-blocklists/master/hostnames.txt > /valhalla/hosts.d/notracking.hosts`;

        break;

    case 'log':
    case 'lo':
    case 'l':
        $logtype = $argv[2] ?? 'dnsmasq';

        switch ($logtype) {
            case 'dnsmasq':
            case 'dn';
            case 'd':
                $file = '/var/log/dnsmasq/dnsmasq.log';

                break;

            case 'squid':
            case 'sq':
            case 's':
                $file = '/var/log/squid/access.log';

                break;

            case 'clear':
            case 'cl':
            case 'c':
                $yn = trim(readline("are you sure you want to clear the logs? [N/y] "));

                if ($yn !== 'y' && $yn !== 'yes') {
                    break 2;
                }

                `echo > /var/log/dnsmasq/dnsmasq.log`;

                colorLine('logs have been cleared', 2);

                break 2;

            case 'rotate':
            case 'ro':
            case 'r':
                $yn = trim(readline("are you sure you want to rotate the dnsmasq log? [N/y] "));

                colorLine('rotating dnsmasq log', 2);

                passthru('logrotate /etc/logrotate.d/dnsmasq');

                colorLine('rotating squid log', 2);

                passthru('logrotate /etc/logrotate.d/squid');

                colorLine('done!', 2);

                break 2;
            default:
                abort('invalid log type');
        }

        colorLine('now tailing ' . $file . '...', 2);

        passthru("tail -f $file");

        break;

    case 'build':
    case 'bu':
    case 'b':
        $mode = $argv[2] ?? $yaml["mode"] ?? null;

        $rules = buildDnsmasqRules($mode);

        # save finalized ruleset
        file_put_contents('/etc/dnsmasq.d/rules', $rules);

        # link configs
        `ln -svf $dir/../system/dnsmasq /etc/dnsmasq.d/valhalla`;

        # restart proxy
        `service dnsmasq restart`;

        # re-register cron file
        `crontab $dir/../system/crontab`;

        # show finishing message
        colorLine("dns rules rebuilt successfully in [$mode] mode!", 2);

        break;

    case 'digest':
    case 'di':
    case 'd':
        $arg = $argv[2] ?? 'allowed';
        $logfile = '/var/log/dnsmasq/dnsmasq.log';

        switch ($arg) {
            case 'allowed':
            case 'al':
            case 'a':
                echo("showing dns requests forwarded to upstream in descending frequency...\n\n");

                passthru("cat $logfile | grep ' forwarded ' | grep '127.0.2.1' |  cut -d' ' -f 6 | sort | uniq -c | sort -r");

                break;

            case 'queried':
            case 'qu':
            case 'q':
                echo "showing dns queries inbound in descending frequency...\n\n";

                passthru("cat $logfile | grep ' query' |  cut -d' ' -f 6 | sort | uniq -c | sort -r");

                break;

            case 'denied':
            case 'de':
            case 'd':
                echo "showing dns requests given 0.0.0.0 in descending frequency...\n\n";

                passthru("cat $logfile | grep ' is 0.0.0.0' | cut -d' ' -f 6 | sort | uniq -c | sort -r");

                break;

            case 'clients':
            case 'cl':
            case 'c':
                echo "showing dns requests per client in descending frequency...\n\n";

                passthru("cat $logfile | grep query | grep from | cut -d' ' -f 8 | sort | uniq -c | sort -r");

                break;

            default:
                abort('invalid digest type');
        }

        break;

    case 'stress':
    case 'st';
    case 's':
        while (true) {
            $u = mt_rand() . ".com";
            colorLine($u, 2);
            dns_get_record($u);
        }

        break;
    default:
        printHelp();

        break;
}

function printHelp()
{
    passthru("tput setaf 2 ; figlet valhalla ; tput sgr0");

    echo <<<EOT
* a highly configurable dns caching virtual server
*
* https://github.com/mmeyer2k/valhalla#command-line-interface
*
* valhalla 
*     build   [tight, loose, off]
*     digest  [allowed, denied, queried, clients] [past]
*     log     [dnsmasq, squid, clear, rotate] [past]
*     stress
*     3p
*     help

EOT;
}

function colorLine(string $msg, ?int $font = null, ?int $bg = null)
{
    $pre = '';

    if ($font !== null) {
        $pre .= "tput setaf $font;";
    }

    if ($bg !== null) {
        $pre .= "tput setab $bg;";
    }

    passthru("$pre echo '$msg' ; tput sgr0");
}

function removeLines(array $input): array
{
    return array_filter(array_map(function ($row) {
        $row = trim($row);

        if (strpos($row, '#') === 0) {
            return null;
        }

        return $row;
    }, $input));
}

function numericOpenvpnConfigList(): array
{
    $ret = [];

    foreach (scandir(__DIR__ . '/../openvpn.d') as $f) {
        if (strpos($f, '.ovpn') !== false) {
            $ret[] = basename($f);
        }
    }

    return $ret;
}

/**
 * get flat array of openvpn authorization files in openvpn.d/
 *
 * @return array
 */
function numericOpenvpnAuthList(): array
{
    $ret = [];

    foreach (scandir(__DIR__ . '/../openvpn.d') as $f) {
        if (strpos($f, '.auth') !== false) {
            $ret[] = basename($f);
        }
    }

    return $ret;
}

function abort(string $message)
{
    colorLine($message, 1);

    die;
}

function parseListsDotD(): array
{
    $lists = [];

    foreach (scandir(__DIR__ . '/../lists.d') as $f) {
        if (pathinfo($f, PATHINFO_EXTENSION) === 'yaml') {
            $parsed = yaml_parse_file(__DIR__ . "/../lists.d/$f");
            $lists = array_merge_recursive($lists, $parsed);
        }
    }

    return $lists;
}

/**
 * turns the yaml files lists.d into dnsmasq rules file string
 *
 * @param string $mode
 * @return string
 */
function buildDnsmasqRules(string &$mode): string
{
    switch ($mode) {
        case 'tight':
        case 'ti':
        case 't':
            $mode = 'tight';
            
            break;

        case 'loose':
        case 'lo':
        case 'l':
            $mode = 'loose';
            
            break;

        case 'off':
        case 'of':
        case 'o':
            $mode = 'off';
            
            break;

        default:
            abort("invalid mode type");
    }

    $rules = [];

    # begin parsing rulesets unless we are in off mode
    if ($mode !== 'off') {
        $lists = parseListsDotD();
        if ($mode === 'tight') {
            foreach (($lists['whitelist'] ?? []) as $row) {
                if (trim($row)) {
                    $rules[] = "server=/.$row/127.0.2.1";
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
    }

    return implode("\r\n", $rules);
}
