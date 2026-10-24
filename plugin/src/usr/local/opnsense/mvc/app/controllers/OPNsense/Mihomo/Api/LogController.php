<?php

namespace OPNsense\Mihomo\Api;

use OPNsense\Base\ApiControllerBase;
use OPNsense\Core\Backend;

class LogController extends ApiControllerBase
{
    public function tailAction()
    {
        $lines = $this->request->get('lines', 'int', 200);
        $lines = (int)$lines;
        if ($lines < 1) {
            $lines = 200;
        }
        if ($lines > 2000) {
            $lines = 2000;
        }

        $backend = new Backend();
        $content = $backend->configdpRun('mihomo log', [(string)$lines]);

        return [
            'result' => 'ok',
            'content' => (string)$content,
        ];
    }
}
