#####################################################
### Criado por Leonardo Santos Silva
### Data: 2 de Outubro de 2023
### Última Revisão: 16 june 2026
### Exercício: 02-Gerenciamento de IP
### Altere as linhas 27 e 28 para refletir o seu ambiente
### O script deve ser repetido até as 3 VNets estarem criadas (tente manter uma lógica para o valor $Sufix (linha 23). Corrija as linhas 134 à 136 para refletir os valore informados durante a execução. 
### Execute o seguinte comando no Azure CLI:
### pwsh -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/corsec00/FIAPTDCCloudSec/main/estruturaRedeAzure.ps1' -OutFile 'estruturaRedeAzure.ps1'; ./estruturaRedeAzure.ps1"
#####################################################
$StartTime = get-date
Clear-Host
# Loga no seu ambiente Azure
# az account clear
az login
# az account list-locations --query "[*].name" | ConvertFrom-Json | sort | where { $_ -like "*us*" }

#Atualizando módulo do Bastion
# az extension add --upgrade -n bastion --allow-preview false

# Cria estrutura de acesso baseado na localidade	
$Loc = Read-Host "Digite o nome da região onde os recursos serão criados (escolha entre northcentralus, westus, westcentralus e northeurope)"  
$RegionGroup = Read-Host "Digite a abreviação para a região onde os recursos serão criados (escolha de acordo com a resposta anterior: ncu, wus, wcu ou neu)"
$Sufix = Read-Host "Digite sufixo dos recursos que serão criados (ex: FIAPLins001 ou VNetAluno001 ou o nome que vc achar necessario)"

# $Sufix = 'leoss001'
$RG = 'RG-Principal'
$DNS = 'CloudSec.leo'
$VNet4 = 'vnet-' +$Sufix
$BST ='bst-'+$RegionGroup +'-' +$Sufix
$PIPBastion = "pip-" +$RegionGroup +'-'+$Sufix
# Definindo o endereçamento de rede
if ($RegionGroup -eq "wus") {
    $ip = "10.10."
} elseif ($RegionGroup -eq "ncu") {
    $ip = "10.20."
} elseif ($RegionGroup -eq "wcu") {
    $ip = "10.30."
} elseif ($RegionGroup -eq "neu") {
    $ip = "10.40."
} else {
    Write-Host "Valor inválido. Por favor, insira ncu, wus, wcu ou neu."
    exit
}
$AddrSpace = $ip +"0.0/16"
$IPBst= $ip +"0.0/27"
$IPWindows = $ip +"10.0/24"
$IPLinux = $ip +"20.0/24"
$IPK8 = $ip +"30.0/24"
$IPFrontEnd = $ip +"40.0/24"
$IPBackEnd = $ip +"50.0/24"

# Criando Zona de DNS Privada. Se já existir, um erro será gerado. 
az network private-dns zone create -g $RG --name $DNS


Write-Host "Para a Região" $Loc "será criado a VNET" $VNet4 "usando o Bastion" $BST "(IP Público:" $PIPBastion") com o Address Space" $AddrSpace "e com as seguintes subnets:"
Write-Host "Rede Bastion:" $IPBst 
Write-Host "Windows:" $IPWindows
Write-Host "Linux:" $IPLinux
Write-Host "Kubernetes:" $IPK8 
Write-Host "Front End Systems:" $IPFrontEnd
Write-Host "Back End Systems::" $IPBackEnd 

# create ASG
az network asg create -g $RG -n asg-$RegionGroup-Kubernetes --location $Loc
az network asg create -g $RG -n asg-$RegionGroup-Windows --location $Loc
az network asg create -g $RG -n asg-$RegionGroup-Linux --location $Loc
az network asg create -g $RG -n asg-$RegionGroup-FrontEnd --location $Loc
az network asg create -g $RG -n asg-$RegionGroup-BackEnd --location $Loc

#Create NSG 
az network nsg create -g $RG -n nsg-$RegionGroup-Linux --location $Loc
az network nsg create -g $RG -n nsg-$RegionGroup-Kubernetes --location $Loc
az network nsg create -g $RG -n nsg-$RegionGroup-Windows --location $Loc
az network nsg create -g $RG -n nsg-$RegionGroup-FrontEnd --location $Loc
az network nsg create -g $RG -n nsg-$RegionGroup-BackEnd --location $Loc

# Create VNet
az network vnet create --resource-group $RG --name $VNet4 --location $Loc --address-prefix $AddrSpace

# Create NSG Kubernetes
az network nsg rule create -g $RG --nsg-name nsg-$RegionGroup-Kubernetes -n Kubernetes-API-Server --destination-asgs asg-$RegionGroup-Kubernetes --priority 2100 --destination-port-ranges 6443  --access Allow --protocol Tcp --source-address-prefixes '*'
az network nsg rule create -g $RG --nsg-name nsg-$RegionGroup-Kubernetes -n Kubelet-API --destination-asgs asg-$RegionGroup-Kubernetes --priority 2101 --destination-port-ranges 10250  --access Allow --protocol Tcp --source-address-prefixes '*'
az network nsg rule create -g $RG --nsg-name nsg-$RegionGroup-Kubernetes -n Kube-Scheduler --destination-asgs asg-$RegionGroup-Kubernetes --priority 2102 --destination-port-ranges 10259  --access Allow --protocol Tcp --source-address-prefixes '*'
az network nsg rule create -g $RG --nsg-name nsg-$RegionGroup-Kubernetes -n Kube-Controler-Manager --destination-asgs asg-$RegionGroup-Kubernetes --priority 2103 --destination-port-ranges 10257  --access Allow --protocol Tcp --source-address-prefixes '*'
az network nsg rule create -g $RG --nsg-name nsg-$RegionGroup-Kubernetes -n SSHInbound --destination-asgs asg-$RegionGroup-Kubernetes --priority 2104 --destination-port-ranges 22  --access Allow --protocol Tcp --source-address-prefixes '*'
az network nsg rule create -g $RG --nsg-name nsg-$RegionGroup-Kubernetes -n etcd-Server-Client-API --destination-asgs asg-$RegionGroup-Kubernetes --priority 2105 --destination-port-ranges 2379-2380  --access Allow --protocol Tcp --source-address-prefixes '*'
az network nsg rule create -g $RG --nsg-name nsg-$RegionGroup-Kubernetes -n NodePort-Services --destination-asgs asg-$RegionGroup-Kubernetes --priority 2106 --destination-port-ranges 30000-32767  --access Allow --protocol Tcp --source-address-prefixes '*'
# Create NSG Linux
az network nsg rule create -g $RG --nsg-name nsg-$RegionGroup-Linux -n SSHInbound --destination-asgs asg-$RegionGroup-Linux --priority 2200 --destination-port-ranges 22  --access Allow --protocol Tcp --source-address-prefixes '*'
# Create NSG Windows
az network nsg rule create -g $RG --nsg-name nsg-$RegionGroup-Windows -n RDPInbound --destination-asgs asg-$RegionGroup-Windows --priority 2300 --destination-port-ranges 3389  --access Allow --protocol Tcp --source-address-prefixes '*'
az network nsg rule create -g $RG --nsg-name nsg-$RegionGroup-Windows -n SMBInbound --destination-asgs asg-$RegionGroup-Windows --priority 2301 --destination-port-ranges 445 139 138 137  --access Allow --protocol '*' --source-address-prefixes '*'

# Create NSG BackEnd
az network nsg rule create -g $RG --nsg-name nsg-$RegionGroup-BackEnd -n Web --destination-asgs asg-$RegionGroup-Windows --priority 2400 --destination-port-ranges 80 443   --access Allow --protocol '*' --source-address-prefixes '*'
az network nsg rule create -g $RG --nsg-name nsg-$RegionGroup-BackEnd -n Mngmnt --destination-asgs asg-$RegionGroup-Windows --priority 2401 --destination-port-ranges 22 3389  --access Allow --protocol '*' --source-address-prefixes '*'

# Create NSG FrontEnd
az network nsg rule create -g $RG --nsg-name nsg-$RegionGroup-FrontEnd -n Web --destination-asgs asg-$RegionGroup-Windows --priority 2500 --destination-port-ranges 80 443   --access Allow --protocol '*' --source-address-prefixes '*'
az network nsg rule create -g $RG --nsg-name nsg-$RegionGroup-FrontEnd -n Mngmnt --destination-asgs asg-$RegionGroup-Windows --priority 2501 --destination-port-ranges 22 3389  --access Allow --protocol '*' --source-address-prefixes '*'

# Create subnets
az network vnet subnet create --resource-group $RG --vnet-name $VNet4 --name AzureBastionSubnet --address-prefix $IPBst
az network vnet subnet create --resource-group $RG --vnet-name $VNet4 --name VM-Windows --address-prefix $IPWindows --network-security-group nsg-$RegionGroup-Windows --private-endpoint-network-policies Enabled
az network vnet subnet create --resource-group $RG --vnet-name $VNet4 --name VM-Linux --address-prefix $IPLinux --network-security-group nsg-$RegionGroup-Linux --private-endpoint-network-policies Enabled
az network vnet subnet create --resource-group $RG --vnet-name $VNet4 --name VM-Kubernetes --address-prefix $IPK8  --network-security-group nsg-$RegionGroup-Kubernetes --private-endpoint-network-policies Enabled
az network vnet subnet create --resource-group $RG --vnet-name $VNet4 --name FrontEnd --address-prefix $IPFrontEnd  --network-security-group nsg-$RegionGroup-FrontEnd --private-endpoint-network-policies Enabled
az network vnet subnet create --resource-group $RG --vnet-name $VNet4 --name BackEnd --address-prefix $IPBackEnd   --network-security-group nsg-$RegionGroup-BackEnd --private-endpoint-network-policies Enabled

# Criando um link entre a VNet e o Private DNS Zone
az network private-dns link vnet create --resource-group $RG --zone-name $DNS --name $DNS --virtual-network $VNet4 --registration-enabled true


# Criando um Bastion
if ($RegionGroup -eq "ncu" -or $RegionGroup -eq "wus") {
    # az network public-ip create --resource-group $RG --name $PIPBastion --sku Standard --location $Loc
    # az network bastion create --name $BST --resource-group $RG --vnet-name $VNet4 --public-ip-address $PIPBastion --sku Developer --location $Loc
    Write-Host "Crie o seu Bastion manualmente, pois via CLI não é aceita a SKU de Developer (gratuito). Use o IP Público" +$PIPBastion
    
} elseif ($RegionGroup -eq "eu2") {
    Write-Host "Não existe Bastion com SKU de Developer nesta Região. O Bastion não será criado."
} else {
    Write-Host "Valor não corresponde a nenhuma condição específica."
}

$condicao = Read-Host "Todas as VNets para estabelecer as parcerias já foram criadas (min 3 - ver os resultados de cada $VNet4)? (S/N)"

# Verifica a entrada do usuário
if ($condicao -eq "S") {
    Write-Host "Criando os Peerings entre as VNets..."

    # Defina as VNets. Esses valores devem ser coletados apos a configuracao de cada uma das VNets
    $VNet1 = 'vnet-FIAPLins001'
    $VNet2 = 'vnet-FIAPLins002'
    $VNet3 = 'vnet-FIAPLins003'
        
    # Obtendo o ID das VNets
        $vnet1Id=(az network vnet show --resource-group $RG --name $VNet1 --query id --output tsv)
        $vnet2Id=(az network vnet show --resource-group $RG --name $VNet2 --query id --output tsv)
        $vnet3Id=(az network vnet show --resource-group $RG --name $VNet3 --query id --output tsv)

        # Criando Peering de 01 para 03
        az network vnet peering create --name VNet01ToVNet03 --resource-group $RG --vnet-name $VNet1 --remote-vnet $vnet3Id --allow-vnet-access
        az network vnet peering create --name VNet03ToVNet01 --resource-group $RG --vnet-name $VNet3 --remote-vnet $vnet1Id --allow-vnet-access

        # Criando Peering de 02 para 03
        az network vnet peering create --name VNet02ToVNet03 --resource-group $RG --vnet-name $VNet2 --remote-vnet $vnet3Id --allow-vnet-access
        az network vnet peering create --name VNet03ToVNet02 --resource-group $RG --vnet-name $VNet3 --remote-vnet $vnet2Id --allow-vnet-access

        # Criando Peering de 01 para 02
        az network vnet peering create --name VNet01ToVNet02 --resource-group $RG --vnet-name $VNet1 --remote-vnet $vnet2Id --allow-vnet-access
        az network vnet peering create --name VNet02ToVNet01 --resource-group $RG --vnet-name $VNet2 --remote-vnet $vnet1Id --allow-vnet-access


} elseif ($input -eq "N") {
    Write-Host "Encerrando o script."
    exit
} else {
    Write-Host "Entrada inválida. Por favor, digite 'S' ou 'N'."
}
$EndTime = get-date
Write-Host "Início --> $StartTime"
Write-Host "Fim   -->  $EndTime"
Write-Host "Não se esqueça de criar o seu Bastion (SKU de Developer não é aceito no CLI)"
