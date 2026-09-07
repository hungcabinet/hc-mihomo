<?php

function mihomo_services()
{
    $services = [];

    $services[] = [
        'description' => gettext('mihomo'),
        'configd' => [
            'restart' => ['mihomo restart'],
            'start' => ['mihomo start'],
            'stop' => ['mihomo stop'],
        ],
        'name' => 'mihomo',
        'pidfile' => '/var/run/mihomo.pid',
    ];

    return $services;
}

function mihomo_configure()
{
    return [
        'newwanip' => ['mihomo_configure_do:2'],
    ];
}

function mihomo_configure_do($verbose = false)
{
    if (file_exists('/var/run/mihomo.stopped')) {
        return;
    }

    if ($verbose) {
        echo 'Restarting mihomo...';
    }

    mwexec('/usr/local/etc/rc.d/mihomo restart');
}

function mihomo_syslog()
{
    $logfacilities = [];
    $logfacilities['mihomo'] = [
        'facility' => ['mihomo'],
    ];

    return $logfacilities;
}
