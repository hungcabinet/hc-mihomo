#!/usr/local/bin/php
<?php

$phalcon = '/usr/local/opnsense/mvc/script/load_phalcon.php';
if (is_file($phalcon)) {
    require_once $phalcon;
} elseif (is_file('/usr/local/etc/inc/config.inc')) {
    require_once '/usr/local/etc/inc/config.inc';
} else {
    exit(0);
}

try {
    if (!class_exists('OPNsense\\Core\\Config') || !class_exists('OPNsense\\Mihomo\\Mihomo')) {
        exit(0);
    }

    $cfg = \OPNsense\Core\Config::getInstance()->object();
    if (isset($cfg->OPNsense->mihomo)) {
        exit(0);
    }

    $oldEnable = false;
    $rc = '/etc/rc.conf.d/mihomo';
    if (is_readable($rc)) {
        $text = file_get_contents($rc);
        if (is_string($text) && preg_match('/^\s*mihomo_enable\s*=\s*"?YES"?/mi', $text)) {
            $oldEnable = true;
        }
    }

    if (!$oldEnable) {
        exit(0);
    }

    $model = new \OPNsense\Mihomo\Mihomo();
    $model->general->enabled = '1';
    $model->serializeToConfig();
    \OPNsense\Core\Config::getInstance()->save();
} catch (\Throwable $e) {
    exit(0);
}
