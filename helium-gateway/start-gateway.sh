#!/bin/bash
echo "Starting start-gateway.sh"

rm -f /etc/helium_gateway/settings.toml

# Download latest Helium settings file
if wget -q -O /etc/helium_gateway/settings.toml.template https://raw.githubusercontent.com/helium/gateway-rs/main/config/default.toml;
then
  echo "Lastest Helium Gateway settings file succesfully downloaded"
else
  echo "ERROR downloading lastest Helium Gateway settings file" 
  exit 1
fi

echo "Checking for I2C device"

mapfile -t data < <(i2cdetect -y 1)

for i in $(seq 1 ${#data[@]}); do
    # shellcheck disable=SC2206
    line=(${data[$i]})
    # shellcheck disable=SC2068
    if echo ${line[@]:1} | grep -q 60; then
        echo "ECC is present."
        ECC_CHIP=True
    else
        echo "ECC is not present."
    fi
done

echo "Setting REGION_OVERRIDE"
if [[ -v REGION_OVERRIDE ]]
then
  echo "REGION_OVERRIDE is set to ${REGION_OVERRIDE}"
  sed -i -e '/region =/ s/= .*/= "'"${REGION_OVERRIDE}"'"/' /etc/helium_gateway/settings.toml.template
else
  echo "REGION_OVERRIDE not set"
  exit 1
fi

echo "Interacting with ECC_CHIP"
if [[ -v ECC_CHIP ]]
then
  echo "Using ECC for public key."
  if [[ -v GW_KEYPAIR ]]
  then
    sed -i -e '/keypair =/ s/= .*/= "'"${GW_KEYPAIR}"'"/' /etc/helium_gateway/settings.toml.template
  else
    sed -i -e '/keypair =/ s/= .*/= "ecc://i2c-1:96&slot=0"/' /etc/helium_gateway/settings.toml.template
  fi
else
  echo "Key file already exists"
  sed -i -e '/keypair =/ s/= .*/= "\/var\/data\/gateway_key.bin"/' /etc/helium_gateway/settings.toml.template
fi

mv /etc/helium_gateway/settings.toml.template /etc/helium_gateway/settings.toml

echo "Calling helium_gateway server ..."
/usr/bin/helium_gateway -c /etc/helium_gateway server

echo "Checking key info..."
if ! PUBLIC_KEYS=$(/usr/bin/helium_gateway -c /etc/helium_gateway key info)
then
  echo "Can't get miner key info"
  #exit 1
else
  echo "$PUBLIC_KEYS" > /var/data/key_json
fi