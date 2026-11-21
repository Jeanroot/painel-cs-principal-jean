#!/bin/bash
clear
echo "===================================================="
echo "🚀 INSTALADOR AUTOMÁTICO PAINEL CS - VERSÃO MODERNA"
echo "===================================================="
sleep 2
export DEBIAN_FRONTEND=noninteractive
timedatectl set-timezone America/Sao_Paulo 2>/dev/null || true
IP_VPS=$(curl -4 -s ifconfig.me)

# 1. LIMPEZA PROFUNDA
echo "[1/9] Limpeza Profunda e Preparação..."
systemctl stop apache2 > /dev/null 2>&1
apt-get purge -y apache2 apache2-utils apache2-bin apache2-data phpmyadmin > /dev/null 2>&1
rm -rf /etc/apache2/ /usr/share/phpmyadmin /var/www/html/painel /var/www/html/phpmyadmin
apt-get update -y > /dev/null 2>&1
apt-get install -y software-properties-common wget curl unzip tar zip > /dev/null 2>&1

# 2. INSTALAÇÃO DO MOTOR E DEPENDÊNCIAS (PHP NATIVO)
echo "[2/9] Instalando Apache, MySQL e PHP Nativos..."
apt-get install -y apache2 mysql-server > /dev/null 2>&1
apt-get install -y php libapache2-mod-php php-mysql php-mbstring php-zip php-gd php-curl php-xml php-bcmath > /dev/null 2>&1

a2dismod mpm_event mpm_worker > /dev/null 2>&1
a2enmod mpm_prefork rewrite > /dev/null 2>&1

# 3. CONFIGURAÇÃO DO APACHE E PHP
echo "[3/9] Configurando Apache e PHP..."
if [ -f "/etc/apache2/apache2.conf" ]; then
    sed -i '/<Directory \/var\/www\/>/,/<\/Directory>/ s/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf
fi

PHP_INI=$(find /etc/php/*/apache2/php.ini 2>/dev/null | head -n 1)
if [ -n "$PHP_INI" ]; then
    sed -i 's/short_open_tag = Off/short_open_tag = On/g' "$PHP_INI"
    sed -i 's/display_errors = Off/display_errors = On/g' "$PHP_INI"
    sed -i 's/upload_max_filesize = .*/upload_max_filesize = 2048M/' "$PHP_INI"
    sed -i 's/post_max_size = .*/post_max_size = 2048M/' "$PHP_INI"
    sed -i 's/memory_limit = .*/memory_limit = 1024M/' "$PHP_INI"
fi

# 4. INSTALAÇÃO DO PHPMYADMIN (ZIP)
echo "[4/9] Instalando phpMyAdmin Oficial..."
cd /var/www/html/
rm -rf phpmyadmin
wget -q https://files.phpmyadmin.net/phpMyAdmin/5.2.1/phpMyAdmin-5.2.1-all-languages.zip
unzip -q phpMyAdmin-5.2.1-all-languages.zip
mv phpMyAdmin-5.2.1-all-languages phpmyadmin
rm -f phpMyAdmin-5.2.1-all-languages.zip

# 5. DOWNLOAD DO PAINEL
echo "[5/9] Baixando o Painel..."
wget -q "https://github.com/Jeanroot/painel-cs-principal-jean/releases/download/v1.0/painel.tar.gz" -O painel.tar.gz
if [ -s "painel.tar.gz" ]; then
    tar -xzf painel.tar.gz 2>/dev/null || unzip -oq painel.tar.gz
    rm -f painel.tar.gz
fi

if [ -f "/var/www/html/painel/.htaccess" ]; then
    sed -i 's/RewriteCond %{HTTPS}/#RewriteCond %{HTTPS}/gI' /var/www/html/painel/.htaccess
    sed -i 's/RewriteRule ^(.*)$ https/#RewriteRule ^(.*)$ https/gI' /var/www/html/painel/.htaccess
fi
mkdir -p /var/www/html/painel/backups /var/lib/php/sessions
chmod -R 777 /var/www/html/painel/backups /var/lib/php/sessions
chown -R www-data:www-data /var/www/html/painel /var/www/html/phpmyadmin /var/lib/php/sessions

# 6. BANCOS DE DADOS E CONEXÃO
echo "[6/9] Importando Bancos de Dados Originais..."
cd /tmp
rm -f *.sql
wget -q "https://github.com/Jeanroot/painel-cs-principal-jean/releases/download/v1.0/acessos.sql" -O acessos.sql
wget -q "https://github.com/Jeanroot/painel-cs-principal-jean/releases/download/v1.0/geral.sql" -O geral.sql
wget -q "https://github.com/Jeanroot/painel-cs-principal-jean/releases/download/v1.0/user.sql" -O user.sql

for file in *.sql; do
    if [ -f "$file" ]; then
        sed -i '/mysqldump:/d' "$file"
        sed -i -E '/CREATE DATABASE/d' "$file"
        sed -i -E '/USE `/d' "$file"
        sed -i 's/DEFINER=`[^` ]*`@`[^` ]*`//g' "$file"
        sed -i 's/utf8mb4_uca1400_ai_ci/utf8mb4_general_ci/g' "$file"
        sed -i '1s/^/SET sql_mode="";\nSET FOREIGN_KEY_CHECKS=0;\n/' "$file"
        echo "SET FOREIGN_KEY_CHECKS=1;" >> "$file"
    fi
done

mysql -e "DROP DATABASE IF EXISTS geral; DROP DATABASE IF EXISTS user; DROP DATABASE IF EXISTS acessos;"
mysql -e "CREATE DATABASE geral CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;"
mysql -e "CREATE DATABASE user CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;"
mysql -e "CREATE DATABASE acessos CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;"

if [ -s "geral.sql" ]; then mysql geral < geral.sql; fi
if [ -s "user.sql" ]; then mysql user < user.sql; fi
if [ -s "acessos.sql" ]; then mysql acessos < acessos.sql; fi

mysql -e "CREATE USER IF NOT EXISTS 'painelcs5.0'@'localhost' IDENTIFIED BY '102030#';"
mysql -e "ALTER USER 'painelcs5.0'@'localhost' IDENTIFIED BY '102030#';"
mysql -e "GRANT ALL PRIVILEGES ON *.* TO 'painelcs5.0'@'localhost' WITH GRANT OPTION; FLUSH PRIVILEGES;"

mkdir -p /var/www/html/painel
cat << 'CONN' > /var/www/html/painel/conexao.php
<?php
date_default_timezone_set('America/Sao_Paulo');
try {
    $connGeral = new PDO("mysql:host=localhost;dbname=geral;charset=utf8mb4", "painelcs5.0", "102030#");
    $connGeral->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    $connUser = new PDO("mysql:host=localhost;dbname=user;charset=utf8mb4", "painelcs5.0", "102030#");
    $connUser->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    $connAcessos = new PDO("mysql:host=localhost;dbname=acessos;charset=utf8mb4", "painelcs5.0", "102030#");
    $connAcessos->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
} catch (PDOException $e) {
    die("<div style='background:#f8d7da; color:#721c24; padding:15px; text-align:center; border-radius:5px; font-family:sans-serif;'><b>⚠️ Erro de Banco de Dados:</b><br>" . $e->getMessage() . "</div>");
}
?>
CONN
chmod 777 /var/www/html/painel/conexao.php

# 7. INJEÇÃO DO REPARADOR AUTOMÁTICO
echo "[7/9] Reparando Bancos e Adicionando Módulos V3..."
cat << 'REPARADOR' > /var/www/html/painel/instalador_completo.php
<?php
require_once 'conexao.php';
@set_time_limit(0);
try { $connUser->exec("SET sql_mode=''"); } catch(Exception $e){}
try { $connGeral->exec("SET sql_mode=''"); } catch(Exception $e){}
try { $connAcessos->exec("SET sql_mode=''"); } catch(Exception $e){}

function checkCol($conn, $tab, $col, $def) {
    try { $conn->query("SELECT $col FROM $tab LIMIT 1"); }
    catch (Exception $e) { try { $conn->exec("SET sql_mode=''"); $conn->exec("ALTER TABLE $tab ADD COLUMN $col $def"); } catch (Exception $e2) {} }
}
function checkTable($conn, $nome, $sql) {
    try { $conn->exec("SET sql_mode=''"); $conn->exec($sql); } catch (Exception $e) {}
}

try { $connUser->exec("ALTER TABLE usuario MODIFY data_cadastro TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL"); } catch (Exception $e) { try { $connUser->exec("ALTER TABLE usuario MODIFY data_cadastro DATETIME DEFAULT CURRENT_TIMESTAMP NOT NULL"); } catch (Exception $ex) {} }
checkCol($connUser, 'usuario', 'id_perfil', "INT(11) DEFAULT 1");
checkCol($connUser, 'usuario', 'dono', "VARCHAR(100) DEFAULT NULL");
checkCol($connUser, 'usuario', 'limite', "INT(11) DEFAULT 0");
checkCol($connUser, 'usuario', 'mac', "VARCHAR(100) DEFAULT NULL");
checkCol($connUser, 'usuario', 'bloqueado', "VARCHAR(10) DEFAULT 'nao'");
checkCol($connUser, 'usuario', 'ValorCobrado', "VARCHAR(50) DEFAULT NULL");
checkCol($connUser, 'usuario', 'vencimento_email_enviado', "INT(1) DEFAULT 0");
checkCol($connUser, 'usuario', 'notas', "TEXT DEFAULT NULL");
checkCol($connUser, 'usuario', 'email', "VARCHAR(255) DEFAULT NULL");

checkTable($connUser, 'mp_revendedores', "CREATE TABLE IF NOT EXISTS mp_revendedores (id INT AUTO_INCREMENT PRIMARY KEY, usuario_revendedor VARCHAR(255) NOT NULL, access_token TEXT DEFAULT NULL, access_token_asaas TEXT DEFAULT NULL) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;");
checkTable($connUser, 'pagamentos', "CREATE TABLE IF NOT EXISTS pagamentos (id INT AUTO_INCREMENT PRIMARY KEY, id_pagamento_mp VARCHAR(255) NOT NULL, usuario_id VARCHAR(255) NOT NULL, status VARCHAR(50) DEFAULT 'pending', valor DECIMAL(10,2) NOT NULL, data_criacao TIMESTAMP DEFAULT CURRENT_TIMESTAMP) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;");

checkCol($connUser, 'rev', 'valor_claro', "DECIMAL(10,2) DEFAULT 0.00");
checkCol($connUser, 'rev', 'valor_net', "DECIMAL(10,2) DEFAULT 0.00");
checkCol($connUser, 'rev', 'nome', "VARCHAR(255) DEFAULT ''");
checkCol($connUser, 'rev', 'whatsapp', "VARCHAR(20) DEFAULT NULL");

checkTable($connUser, 'configuracoes_pagamento', "CREATE TABLE IF NOT EXISTS configuracoes_pagamento (id INT AUTO_INCREMENT PRIMARY KEY, access_token VARCHAR(255), public_key VARCHAR(255), client_id VARCHAR(255), client_secret VARCHAR(255), valor_padrao DECIMAL(10,2) DEFAULT 30.00, tipo VARCHAR(50) DEFAULT 'mercadopago') ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;");
checkTable($connUser, 'rev_perfil', "CREATE TABLE IF NOT EXISTS rev_perfil (id INT AUTO_INCREMENT PRIMARY KEY, id_rev INT, id_perfil INT, valor_custo DECIMAL(10,2) DEFAULT 0.00) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;");

checkCol($connUser, 'teste', 'email', "VARCHAR(255) DEFAULT NULL");
checkCol($connUser, 'teste', 'celular', "VARCHAR(50) DEFAULT NULL");

checkTable($connGeral, 'config_api_whatsapp', "CREATE TABLE IF NOT EXISTS config_api_whatsapp (id INT AUTO_INCREMENT PRIMARY KEY, usuario VARCHAR(100) NOT NULL, api_url VARCHAR(255) DEFAULT NULL, api_key VARCHAR(255) DEFAULT NULL, instancia VARCHAR(100) DEFAULT NULL, status VARCHAR(20) DEFAULT 'desconectado') ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;");
checkTable($connGeral, 'config_msg_rev', "CREATE TABLE IF NOT EXISTS config_msg_rev (id INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY, msg_novo TEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci, msg_cobranca TEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci, cron_hora VARCHAR(5) DEFAULT '10:00', cron_status VARCHAR(10) DEFAULT 'ativo', cpf_admin VARCHAR(20) DEFAULT '', ultima_execucao DATE DEFAULT NULL) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;");

checkCol($connGeral, 'config_msg_rev', 'cpf_admin', "VARCHAR(20) DEFAULT ''");

$connGeral->exec("INSERT IGNORE INTO config_msg_rev (id, msg_novo, msg_cobranca, cron_hora, cron_status) VALUES (1, '*🎉 BOAS VINDAS AO NOSSO SERVIDOR! 🎉*\\n\\n*🚀 ACESSO REVENDA*\\n\\n👤 *User:* {usuario}\\n🔑 *Senha:* {senha}\\n🔗 *Painel:* {link_painel}\\n📅 *Venc:* {vencimento}\\n\\n_Guarde esses dados com segurança!_', '🚨 *Aviso de Vencimento!* 🚨\\n\\nOlá {nome}, o seu painel de revenda vence em *{dias} dias*!\\n\\nVocê tem {qtd_ativos} clientes e a sua fatura gerada é de *{total_pagar}*\\n\\nPague sua fatura clicando no link abaixo:\\n{link_painel}/servidor/fatura.php?u={usuario}\\n\\nRenove com antecedência para evitar bloqueios.', '10:00', 'ativo')");

checkTable($connGeral, 'servidor', "CREATE TABLE IF NOT EXISTS servidor (id INT AUTO_INCREMENT PRIMARY KEY, nome VARCHAR(100), url VARCHAR(255), porta VARCHAR(10), usuario VARCHAR(100), senha VARCHAR(100), tipo VARCHAR(50) DEFAULT 'csp', ip VARCHAR(50)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;");
checkCol($connGeral, 'servidor', 'tipo', "VARCHAR(50) DEFAULT 'csp'");

checkTable($connGeral, 'perfil', "CREATE TABLE IF NOT EXISTS perfil (id INT AUTO_INCREMENT PRIMARY KEY, nome VARCHAR(100), url VARCHAR(255), porta VARCHAR(10), tipo VARCHAR(50)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;");
checkTable($connGeral, 'arquivo_backup', "CREATE TABLE IF NOT EXISTS arquivo_backup (id INT AUTO_INCREMENT PRIMARY KEY, tipo VARCHAR(50) DEFAULT 'Manual', local VARCHAR(255) NOT NULL, data DATETIME DEFAULT CURRENT_TIMESTAMP, size VARCHAR(50) DEFAULT '0 KB', link_externo VARCHAR(255) DEFAULT NULL) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;");
checkCol($connGeral, 'arquivo_backup', 'link_externo', "VARCHAR(255) DEFAULT NULL");

checkTable($connGeral, 'backup_automatizado', "CREATE TABLE IF NOT EXISTS backup_automatizado (id INT NOT NULL PRIMARY KEY, status VARCHAR(20) DEFAULT 'inativo', tempo VARCHAR(20) DEFAULT 'diario', horario VARCHAR(10) DEFAULT '03:00') ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;");
$connGeral->exec("INSERT IGNORE INTO backup_automatizado (id) VALUES (1)");

checkTable($connGeral, 'smtp_config', "CREATE TABLE IF NOT EXISTS smtp_config (id INT AUTO_INCREMENT PRIMARY KEY, host VARCHAR(255), email VARCHAR(255), senha VARCHAR(255), porta VARCHAR(10), seguranca VARCHAR(20)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;");
checkTable($connGeral, 'mascaraurl', "CREATE TABLE IF NOT EXISTS mascaraurl (id INT AUTO_INCREMENT PRIMARY KEY, nome VARCHAR(100), url VARCHAR(255), porta VARCHAR(10)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;");

checkTable($connAcessos, 'logs', "CREATE TABLE IF NOT EXISTS logs (id INT AUTO_INCREMENT PRIMARY KEY, mensagem TEXT, data DATETIME DEFAULT CURRENT_TIMESTAMP, ip VARCHAR(50), usuario VARCHAR(100)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;");
checkTable($connAcessos, 'acessos', "CREATE TABLE IF NOT EXISTS acessos (id INT AUTO_INCREMENT PRIMARY KEY, usuario VARCHAR(100), ip VARCHAR(50), data DATETIME DEFAULT CURRENT_TIMESTAMP, status VARCHAR(50)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;");
checkTable($connAcessos, 'log_disparos', "CREATE TABLE IF NOT EXISTS log_disparos (id INT AUTO_INCREMENT PRIMARY KEY, origem VARCHAR(255) NOT NULL, resumo VARCHAR(255) NOT NULL, status VARCHAR(50) NOT NULL, data_log TIMESTAMP DEFAULT CURRENT_TIMESTAMP) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;");

$stmt = $connUser->query("SELECT id, data_premio FROM usuario");
if($stmt) {
    while($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        $d = $row['data_premio'];
        if(empty($d) || $d == '0' || $d == '0000-00-00' || (is_numeric($d) && $d < 0)) {
            $hoje = date('Y-m-d');
            $connUser->query("UPDATE usuario SET data_premio = '$hoje' WHERE id = {$row['id']}");
        }
        elseif(is_numeric($d) && $d > 100000) {
            $nova = date('Y-m-d', $d);
            $connUser->query("UPDATE usuario SET data_premio = '$nova' WHERE id = {$row['id']}");
        }
    }
}
?>
REPARADOR

cd /var/www/html/painel && php instalador_completo.php > /dev/null 2>&1

# 8. CRON JOBS SEGUROS (COM FLOCK)
echo "[8/9] Criando Cron Jobs Automáticos Seguros..."
crontab -r 2>/dev/null
CRONTAB_TMP="/tmp/crontab_painel"
cat << 'CRON' > $CRONTAB_TMP
*/5 * * * * /usr/bin/flock -n /tmp/painel_cobrancas_rev.lock /usr/bin/php -q /var/www/html/painel/cron_cobrancas_rev.php >/dev/null 2>&1
*/5 * * * * /usr/bin/flock -n /tmp/painel_cobrancas.lock /usr/bin/php -q /var/www/html/painel/cron_cobrancas.php >/dev/null 2>&1
*/5 * * * * /usr/bin/flock -n /tmp/painel_clientes.lock /usr/bin/php -q /var/www/html/painel/cron_clientes.php >/dev/null 2>&1
48 0,12 * * * /usr/bin/flock -n /tmp/painel_backup.lock /usr/bin/php -q /var/www/html/painel/backup.php >/dev/null 2>&1
50 0,12 * * * /usr/bin/flock -n /tmp/painel_backup_bd.lock /usr/bin/php -q /var/www/html/painel/backup_bd.php >/dev/null 2>&1
52 0,12 * * * /usr/bin/flock -n /tmp/painel_funcao_backup.lock /usr/bin/php -q /var/www/html/painel/funcao_backup.php >/dev/null 2>&1
*/5 * * * * /usr/bin/flock -n /tmp/serv_cobrancas_rev.lock /usr/bin/php -q /var/www/html/painel/servidor/cron_cobrancas_rev.php >/dev/null 2>&1
*/5 * * * * /usr/bin/flock -n /tmp/serv_cobrancas.lock /usr/bin/php -q /var/www/html/painel/servidor/cron_cobrancas.php >/dev/null 2>&1
*/5 * * * * /usr/bin/flock -n /tmp/serv_clientes.lock /usr/bin/php -q /var/www/html/painel/servidor/cron_clientes.php >/dev/null 2>&1
54 0,12 * * * /usr/bin/flock -n /tmp/serv_backup.lock /usr/bin/php -q /var/www/html/painel/servidor/backup.php >/dev/null 2>&1
56 0,12 * * * /usr/bin/flock -n /tmp/serv_backup_bd.lock /usr/bin/php -q /var/www/html/painel/servidor/backup_bd.php >/dev/null 2>&1
58 0,12 * * * /usr/bin/flock -n /tmp/serv_funcao_backup.lock /usr/bin/php -q /var/www/html/painel/servidor/funcao_backup.php >/dev/null 2>&1
CRON
crontab $CRONTAB_TMP
rm -f $CRONTAB_TMP

# 9. REINÍCIO DOS MOTORES E PORTAS
echo "[9/9] Reiniciando Servicos..."
ufw allow 80/tcp > /dev/null 2>&1
ufw allow 443/tcp > /dev/null 2>&1
systemctl restart apache2
systemctl restart mysql

URL_FINAL="http://$IP_VPS/painel"
URL_BD="http://$IP_VPS/phpmyadmin"

clear
echo "===================================================="
echo "✅ TUDO PRONTO! PAINEL V3 INSTALADO COM SUCESSO"
echo "===================================================="
echo ""
echo "🔗 Link do Painel: $URL_FINAL"
echo "🔗 Link do Banco:  $URL_BD"
echo "👤 Usuário Banco:  painelcs5.0"
echo "🔑 Senha Banco:    102030#"
echo ""
echo "OBS: As tabelas do V3 já foram geradas automaticamente!"
echo "===================================================="
