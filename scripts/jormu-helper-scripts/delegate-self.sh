#!/bin/sh

# Disclaimer:
#
#  The following use of shell script is for demonstration and understanding
#  only, it should *NOT* be used at scale or for any sort of serious
#  deployment, and is solely used for learning how the node and blockchain
#  works, and how to interact with everything.
#
#  It also asumes that `jcli` is in the same folder with the script.
#
#  Tutorials can be found here: https://github.com/input-output-hk/shelley-testnet/wiki

. $(dirname $0)/env

if [ $# -ne 3 ]; then
    echo "usage: $0 <REST-LISTEN-PORT> <ACCOUNT_SK> <STAKE_POOL_ID>"
    echo "    <REST-PORT>      The REST Listen Port set in node-config.yaml file (EX: 3101)"
    echo "    <ACCOUNT_SK>     The Secret key of the Account address"
    echo "    <STAKE_POOL_ID>  The ID of the Stake Pool you want to delegate to"
    exit 1
fi

REST_PORT="$1"
ACCOUNT_SK="$2"
STAKE_POOL_ID="$3"

[ -f ${ACCOUNT_SK} ] && ACCOUNT_SK=$(cat ${ACCOUNT_SK})

REST_URL="http://127.0.0.1:${REST_PORT}/api"
BLOCK0_HASH=$($CLI rest v0 settings get -h "${REST_URL}" | grep 'block0Hash:' | sed -e 's/^[[:space:]]*//' | sed -e 's/block0Hash: //')
FEE_CONSTANT=$($CLI rest v0 settings get -h "${REST_URL}" | grep 'constant:' | sed -e 's/^[[:space:]]*//' | sed -e 's/constant: //')
FEE_COEFFICIENT=$($CLI rest v0 settings get -h "${REST_URL}" | grep 'coefficient:' | sed -e 's/^[[:space:]]*//' | sed -e 's/coefficient: //')
FEE_CERTIFICATE=$($CLI rest v0 settings get -h "${REST_URL}" | grep 'certificate_owner_stake_delegation:' | sed -e 's/^[[:space:]]*//' | sed -e 's/certificate_owner_stake_delegation: //')

echo "================DELEGATE ACCOUNT================="
echo "REST_PORT: ${REST_PORT}"
echo "ACCOUNT_SK: ${ACCOUNT_SK}"
echo "BLOCK0_HASH: ${BLOCK0_HASH}"
echo "FEE_CONSTANT: ${FEE_CONSTANT}"
echo "FEE_COEFFICIENT: ${FEE_COEFFICIENT}"
echo "FEE_CERTIFICATE: ${FEE_CERTIFICATE}"
echo "=================================================="

STAGING_FILE="staging.$$.transaction"

#CLI transaction
if [ -f "${STAGING_FILE}" ]; then
    echo "error: staging already exist. restart"
    exit 2
fi

ACCOUNT_PK=$(echo ${ACCOUNT_SK} | $CLI key to-public)
ACCOUNT_ADDR=$($CLI address account ${ADDRTYPE} ${ACCOUNT_PK})

echo " ##1. Create the delegation certificate for the Account address"

ACCOUNT_SK_FILE="account.prv"
CERTIFICATE_FILE="account_delegation_certificate"
echo ${ACCOUNT_SK} > ${ACCOUNT_SK_FILE}

$CLI certificate new owner-stake-delegation \
    ${STAKE_POOL_ID} \
    -o ${CERTIFICATE_FILE}

ACCOUNT_COUNTER=$( $CLI rest v0 account get "${ACCOUNT_ADDR}" -h "${REST_URL}" | grep '^counter:' | sed -e 's/counter: //' )
ACCOUNT_AMOUNT=$((${FEE_CONSTANT} + ${FEE_COEFFICIENT} + ${FEE_CERTIFICATE}))

echo " ##2. Create the offline delegation transaction for the Account address"
$CLI transaction new --staging ${STAGING_FILE}

echo " ##3. Add input account to the transaction"
$CLI transaction add-account "${ACCOUNT_ADDR}" "${ACCOUNT_AMOUNT}" --staging "${STAGING_FILE}"

echo " ##4. Add the certificate to the transaction"
cat ${CERTIFICATE_FILE} | xargs $CLI transaction add-certificate --staging ${STAGING_FILE}

echo " ##5. Finalize the transaction"
$CLI transaction finalize --staging ${STAGING_FILE}

# get the transaction id
TRANSACTION_ID=$($CLI transaction id --staging ${STAGING_FILE})

echo " ##6. Create the withness"
WITNESS_SECRET_FILE="witness.secret.$$"
WITNESS_OUTPUT_FILE="witness.out.$$"
printf "${ACCOUNT_SK}" > ${WITNESS_SECRET_FILE}

$CLI transaction make-witness ${TRANSACTION_ID} \
    --genesis-block-hash ${BLOCK0_HASH} \
    --type "account" --account-spending-counter "${ACCOUNT_COUNTER}" \
    ${WITNESS_OUTPUT_FILE} ${WITNESS_SECRET_FILE}

echo " ##7. Add the witness to the transaction"
$CLI transaction add-witness ${WITNESS_OUTPUT_FILE} --staging "${STAGING_FILE}"

echo " ##8. Show the transaction info"
$CLI transaction info --fee-constant ${FEE_CONSTANT} --fee-coefficient ${FEE_COEFFICIENT} --fee-certificate ${FEE_CERTIFICATE} --staging "${STAGING_FILE}"

echo " ##9. Finalize the transaction and send it to the blockchain"
$CLI transaction seal --staging "${STAGING_FILE}"
$CLI transaction auth -k ${ACCOUNT_SK_FILE} --staging "${STAGING_FILE}"
$CLI transaction to-message --staging "${STAGING_FILE}" | $CLI rest v0 message post -h "${REST_URL}"

waitNewBlockCreated

echo " ##10. Check the account's delegation status"
$CLI rest v0 account get ${ACCOUNT_ADDR} -h ${REST_URL}

rm ${STAGING_FILE} ${ACCOUNT_SK_FILE} ${CERTIFICATE_FILE} ${WITNESS_SECRET_FILE} ${WITNESS_OUTPUT_FILE}

exit 0
