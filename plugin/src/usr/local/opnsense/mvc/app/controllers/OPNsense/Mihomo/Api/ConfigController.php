<?php

namespace OPNsense\Mihomo\Api;

use OPNsense\Base\ApiControllerBase;
use OPNsense\Core\Backend;

class ConfigController extends ApiControllerBase
{
    private const INCOMING = '/tmp/mihomo.incoming.yaml';
    private const MAX_BYTES = 8388608;

    public function getAction()
    {
        $backend = new Backend();
        $content = $backend->configdRun('mihomo config-get');

        return [
            'result' => 'ok',
            'content' => (string)$content,
        ];
    }

    public function setAction()
    {
        if (!$this->request->isPost()) {
            return ['result' => 'failed', 'message' => gettext('POST required.')];
        }

        $content = $this->request->getPost('content');
        if (!is_string($content)) {
            $content = '';
        }

        return $this->stageAndApply($content);
    }

    public function downloadAction()
    {
        $payload = $this->getAction();
        $payload['filename'] = 'config.yaml';

        return $payload;
    }

    public function uploadAction()
    {
        if (!$this->request->isPost()) {
            return ['result' => 'failed', 'message' => gettext('POST required.')];
        }

        $files = $this->request->getUploadedFiles(true);
        if (empty($files)) {
            return ['result' => 'failed', 'message' => gettext('No file uploaded.')];
        }

        $upload = null;
        foreach ($files as $file) {
            $key = method_exists($file, 'getKey') ? (string)$file->getKey() : '';
            if ($key === 'config' || $key === 'file' || $upload === null) {
                $upload = $file;
                if ($key === 'config' || $key === 'file') {
                    break;
                }
            }
        }

        if ($upload === null) {
            return ['result' => 'failed', 'message' => gettext('No file uploaded.')];
        }

        if ((int)$upload->getSize() > self::MAX_BYTES) {
            return ['result' => 'failed', 'message' => gettext('Config larger than 8 MiB.')];
        }

        $tmpName = $upload->getTempName();
        if (!is_string($tmpName) || !is_readable($tmpName)) {
            return ['result' => 'failed', 'message' => gettext('Unable to read the uploaded file.')];
        }

        $content = file_get_contents($tmpName);
        if ($content === false) {
            return ['result' => 'failed', 'message' => gettext('Unable to read the uploaded file.')];
        }

        return $this->stageAndApply($content);
    }

    private function stageAndApply($content)
    {
        if (strlen($content) > self::MAX_BYTES) {
            return ['result' => 'failed', 'message' => gettext('Config larger than 8 MiB.')];
        }

        if (file_put_contents(self::INCOMING, $content, LOCK_EX) === false) {
            return ['result' => 'failed', 'message' => gettext('Unable to stage the config.')];
        }
        @chmod(self::INCOMING, 0600);

        $backend = new Backend();
        $output = $backend->configdRun('mihomo config-set');

        return $this->parseApplyOutput($output);
    }

    private function parseApplyOutput($output)
    {
        $output = str_replace("\r\n", "\n", (string)$output);
        $output = preg_replace('/\n+$/', '', $output);
        $lines = explode("\n", $output);
        while ($lines !== [] && $lines[0] === '') {
            array_shift($lines);
        }
        $code = array_shift($lines);
        $body = implode("\n", $lines);

        if ($code === 'OK') {
            $reloaded = strpos($body, 'reloaded=1') !== false;
            return [
                'result' => 'ok',
                'reloaded' => $reloaded,
                'message' => $reloaded
                    ? gettext('Config saved and the service was restarted.')
                    : gettext('Config saved.'),
            ];
        }

        if ($code === 'FAILED') {
            return [
                'result' => 'failed',
                'message' => $body !== '' ? $body : gettext('Config validation failed.'),
            ];
        }

        return [
            'result' => 'failed',
            'message' => $output !== '' ? $output : gettext('Unexpected response from configd.'),
        ];
    }
}
