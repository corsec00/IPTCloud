#####################################################
### Created by Leonardo Santos Silva
### Data: 15 September 2023
### Última Revisão: 16 june 2026
#####################################################

Clear-Host

# Variables
$RootCA = Read-Host "Nome do seu ROOT CA"  
$CertName = Read-Host "CN (Common Nome) do Certificado (URL ou e-mail) "  
$Senha = Read-Host "Senha para o ROOT CA " -AsSecureString
$Senhabase64 = ConvertTo-SecureString -String $Senha -Force -AsPlainText

# Create ROOT CA
$params = @{
    Type = 'Custom'
    Subject = $RootCA
    KeySpec = 'Signature'
    KeyExportPolicy = 'Exportable'
    KeyUsage = 'CertSign'
    KeyUsageProperty = 'Sign'
    KeyLength = 2048
    HashAlgorithm = 'sha256'
    NotAfter = (Get-Date).AddMonths(24)
    # If you need to include SANs
    # DnsName = 'vpngw000000.leoseg.cloud', 'vpngw000001.leoseg.cloud', 'vpngtw-leoss001.leosantos.seg.br'
    CertStoreLocation = 'Cert:\CurrentUser\My'
}
$certROOT = New-SelfSignedCertificate @params
# $certROOT = New-SelfSignedCertificate -Type 'Custom' -Subject $RootCA -KeySpec 'Signature' -KeyExportPolicy 'Exportable' -KeyUsage 'CertSign' -KeyUsageProperty 'Sign' -KeyLength 2048 -HashAlgorithm 'sha256' -NotAfter (Get-Date).AddMonths(24) -DnsName 'vpngw000000.leoseg.cloud', 'vpngw000001.leoseg.cloud', 'vpngtw-leoss001.leosantos.seg.br' -CertStoreLocation 'Cert:\CurrentUser\My'


$certROOT

# Export ROOT CA Configurations
$myROOTThumbprint = Get-ChildItem -Path "Cert:\CurrentUser\My" | Where-Object { $_.Subject -like "*$RootCA*" } | Select-Object -ExpandProperty Thumbprint
$certThumb = Get-ChildItem -Path "Cert:\CurrentUser\My\$myROOTThumbprint"

# Create a Client Certificate
$params = @{
    Type = 'Custom'
    Subject = $CertName
    DnsName = $CertName
    KeySpec = 'Signature'
    KeyExportPolicy = 'Exportable'
    KeyLength = 2048
    HashAlgorithm = 'sha256'
    NotAfter = (Get-Date).AddMonths(18)
    CertStoreLocation = 'Cert:\CurrentUser\My'
    Signer = $certROOT
    TextExtension = @(
     '2.5.29.37={text}1.3.6.1.5.5.7.3.2')
}
New-SelfSignedCertificate @params

Start-Sleep -Seconds 2

# Export Certs to PFX 
$myClientThumbprint = Get-ChildItem -Path "Cert:\CurrentUser\My" | Where-Object { $_.Subject -like "*$CertName*" } | Select-Object -ExpandProperty Thumbprint
$PathRoot = $RootCA+".pfx"
$PathCllient = $CertName+".pfx"
$SenhaCert = Read-Host "Password store certificates " -AsSecureString
Export-PfxCertificate -Cert "Cert:\CurrentUser\My\$myROOTThumbprint" -FilePath $PathRoot -Password $SenhaCert
Export-PfxCertificate -Cert "Cert:\CurrentUser\My\$myClientThumbprint" -FilePath $PathCllient -Password $SenhaCert
