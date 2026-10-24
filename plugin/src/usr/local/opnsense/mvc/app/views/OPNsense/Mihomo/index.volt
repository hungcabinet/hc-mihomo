<script>
    $(function () {
        const i18n = {
            running: "{{ lang._('Running') }}",
            stopped: "{{ lang._('Stopped') }}",
            disabled: "{{ lang._('Disabled') }}",
            unknown: "{{ lang._('Unknown') }}",
            requestFailed: "{{ lang._('Request failed.') }}",
            noFile: "{{ lang._('Choose a YAML file first.') }}"
        };

        function statusLabel(status) {
            switch (status) {
                case 'running':
                    return '<span class="label label-success">' + i18n.running + '</span>';
                case 'stopped':
                    return '<span class="label label-danger">' + i18n.stopped + '</span>';
                case 'disabled':
                    return '<span class="label label-default">' + i18n.disabled + '</span>';
                default:
                    return '<span class="label label-warning">' + i18n.unknown + '</span>';
            }
        }

        function setBusy($button, busy) {
            $button.prop('disabled', busy);
            $button.find('.fa-spinner').toggle(busy);
        }

        function showAlert(kind, message) {
            const $box = $('#mihomoAlert');
            $box.removeClass('hidden alert-success alert-danger alert-info')
                .addClass(kind === 'ok' ? 'alert-success' : 'alert-danger')
                .text(message);
        }

        function clearAlert() {
            $('#mihomoAlert').addClass('hidden').text('');
        }

        function refreshStatus() {
            ajaxGet('/api/mihomo/service/info', {}, function (data) {
                if (!data) {
                    return;
                }
                $('#svcStatus').html(statusLabel(data.status));
                $('#svcDetail').text(data.detail || '');
                $('#svcVersion').text(data.version || '');
                updateServiceControlUI('mihomo');
            });
        }

        function refreshLog() {
            ajaxGet('/api/mihomo/log/tail', {lines: 200}, function (data) {
                if (!data || data.result !== 'ok') {
                    return;
                }
                $('#logView').text(data.content || '');
                const node = document.getElementById('logView');
                if (node) {
                    node.scrollTop = node.scrollHeight;
                }
            });
        }

        function refreshConfig() {
            ajaxGet('/api/mihomo/config/get', {}, function (data) {
                if (!data || data.result !== 'ok') {
                    return;
                }
                $('#configYaml').val(data.content || '');
            });
        }

        function serviceCall(action, $button) {
            clearAlert();
            setBusy($button, true);
            ajaxCall('/api/mihomo/service/' + action, {}, function (data, status) {
                setBusy($button, false);
                if (status !== 'success') {
                    showAlert('failed', i18n.requestFailed);
                }
                refreshStatus();
                refreshLog();
            });
        }

        function applyResult(data, status) {
            if (status !== 'success' || !data) {
                showAlert('failed', i18n.requestFailed);
                return;
            }
            if (data.result === 'ok') {
                showAlert('ok', data.message || '');
                refreshConfig();
                refreshStatus();
                refreshLog();
                return;
            }
            showAlert('failed', data.message || i18n.requestFailed);
        }

        updateServiceControlUI('mihomo');
        refreshStatus();
        refreshLog();
        refreshConfig();

        $('#btnStart').on('click', function () { serviceCall('start', $(this)); });
        $('#btnStop').on('click', function () { serviceCall('stop', $(this)); });
        $('#btnRestart').on('click', function () { serviceCall('restart', $(this)); });
        $('#btnRefreshStatus').on('click', function () { refreshStatus(); });
        $('#btnRefreshLog').on('click', function () { refreshLog(); });
        $('#btnReloadConfig').on('click', function () { refreshConfig(); });

        $('#btnSave').on('click', function () {
            const $button = $(this);
            clearAlert();
            setBusy($button, true);
            ajaxCall('/api/mihomo/config/set', {content: $('#configYaml').val()}, function (data, status) {
                setBusy($button, false);
                applyResult(data, status);
            });
        });

        $('#btnDownload').on('click', function () {
            ajaxGet('/api/mihomo/config/download', {}, function (data) {
                if (!data || data.result !== 'ok') {
                    showAlert('failed', i18n.requestFailed);
                    return;
                }
                const blob = new Blob([data.content || ''], {type: 'text/yaml'});
                const url = URL.createObjectURL(blob);
                const link = document.createElement('a');
                link.href = url;
                link.download = data.filename || 'config.yaml';
                document.body.appendChild(link);
                link.click();
                document.body.removeChild(link);
                URL.revokeObjectURL(url);
            });
        });

        $('#btnUpload').on('click', function () {
            const file = document.getElementById('configFile').files[0];
            if (!file) {
                showAlert('failed', i18n.noFile);
                return;
            }
            const $button = $(this);
            clearAlert();
            setBusy($button, true);
            const form = new FormData();
            form.append('config', file);
            $.ajax({
                url: '/api/mihomo/config/upload',
                type: 'POST',
                data: form,
                processData: false,
                contentType: false
            }).done(function (data) {
                setBusy($button, false);
                applyResult(data, 'success');
                $('#configFile').val('');
            }).fail(function () {
                setBusy($button, false);
                showAlert('failed', i18n.requestFailed);
            });
        });
    });
</script>

<div class="alert hidden" id="mihomoAlert"></div>

<div class="content-box" style="padding-bottom: 1.5em;">
    <div class="table-responsive">
        <table class="table table-striped">
            <tbody>
                <tr>
                    <td style="width: 22%;"><strong>{{ lang._('Status') }}</strong></td>
                    <td id="svcStatus"></td>
                </tr>
                <tr>
                    <td><strong>{{ lang._('Details') }}</strong></td>
                    <td><pre id="svcDetail" style="margin: 0; white-space: pre-wrap;"></pre></td>
                </tr>
                <tr>
                    <td><strong>{{ lang._('Version') }}</strong></td>
                    <td><pre id="svcVersion" style="margin: 0; white-space: pre-wrap;"></pre></td>
                </tr>
            </tbody>
        </table>
    </div>
    <div class="col-md-12">
        <button class="btn btn-primary" id="btnStart" type="button">
            <span class="fa fa-spinner fa-pulse" style="display: none;"></span>
            {{ lang._('Start') }}
        </button>
        <button class="btn btn-default" id="btnStop" type="button">
            <span class="fa fa-spinner fa-pulse" style="display: none;"></span>
            {{ lang._('Stop') }}
        </button>
        <button class="btn btn-default" id="btnRestart" type="button">
            <span class="fa fa-spinner fa-pulse" style="display: none;"></span>
            {{ lang._('Restart') }}
        </button>
        <button class="btn btn-default" id="btnRefreshStatus" type="button">{{ lang._('Refresh') }}</button>
    </div>
    <div class="col-md-12" style="margin-top: 0.8em;">
        <small class="text-muted">
            {{ lang._('Start and Stop from this page survive a reboot. A shell stop only lasts until the next boot.') }}
        </small>
    </div>
</div>

<div class="content-box" style="margin-top: 1.2em; padding-bottom: 1.5em;">
    <div class="table-responsive">
        <table class="table table-striped">
            <thead>
                <tr>
                    <th>{{ lang._('Log') }}</th>
                </tr>
            </thead>
            <tbody>
                <tr>
                    <td>
                        <pre id="logView" class="pre-scrollable" style="max-height: 20em; font-family: Menlo, Consolas, monospace; font-size: 12px;"></pre>
                    </td>
                </tr>
            </tbody>
        </table>
    </div>
    <div class="col-md-12">
        <button class="btn btn-default" id="btnRefreshLog" type="button">{{ lang._('Refresh log') }}</button>
        <a class="btn btn-default" href="/ui/diagnostics/log/core/mihomo">{{ lang._('Open system log') }}</a>
    </div>
</div>

<div class="content-box" style="margin-top: 1.2em; padding-bottom: 1.5em;">
    <div class="table-responsive">
        <table class="table table-striped">
            <thead>
                <tr>
                    <th>{{ lang._('config.yaml') }}</th>
                </tr>
            </thead>
            <tbody>
                <tr>
                    <td>
                        <textarea id="configYaml" class="form-control" rows="24" spellcheck="false" style="font-family: Menlo, Consolas, monospace; font-size: 12px;"></textarea>
                    </td>
                </tr>
            </tbody>
        </table>
    </div>
    <div class="col-md-12">
        <button class="btn btn-primary" id="btnSave" type="button">
            <span class="fa fa-spinner fa-pulse" style="display: none;"></span>
            {{ lang._('Save') }}
        </button>
        <button class="btn btn-default" id="btnReloadConfig" type="button">{{ lang._('Reload from disk') }}</button>
        <button class="btn btn-default" id="btnDownload" type="button">{{ lang._('Download') }}</button>
        <input id="configFile" type="file" accept=".yaml,.yml,text/yaml,text/plain" style="display: inline-block; max-width: 22em;">
        <button class="btn btn-default" id="btnUpload" type="button">
            <span class="fa fa-spinner fa-pulse" style="display: none;"></span>
            {{ lang._('Upload') }}
        </button>
    </div>
    <div class="col-md-12" style="margin-top: 0.8em;">
        <small class="text-muted">
            {{ lang._('Save and upload run mihomo -t first. The live file is replaced only when validation succeeds. Maximum size is 8 MiB.') }}
        </small>
    </div>
</div>
