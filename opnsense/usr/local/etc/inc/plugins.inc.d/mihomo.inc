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

function mihomo_configure_do($verbose = false, $interfaces = null)
{
    if (file_exists('/var/run/mihomo.stopped')) {
        return;
    }

    service_log('Restarting mihomo...', $verbose);
    mwexecf('%s restart', '/usr/local/etc/rc.d/mihomo');
    service_log("done.\n", $verbose);
}

function mihomo_syslog()
{
    $logfacilities = [];
    $logfacilities['mihomo'] = [
        'facility' => ['mihomo'],
    ];

    return $logfacilities;
}
