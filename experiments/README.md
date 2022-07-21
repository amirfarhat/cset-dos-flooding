# Contents

This subdirectory contains groupings of experiments used to generate numeric results, tables, and figures in the paper. Each experiment comes in the form of a `.zip` file. The experiment groups and their included experiments are below:

- **cloud**: Experiments with the cloud topology which vary attack rates and network protocols.
  - cloud_proxy_and_attacker_withattacker_httpson
  - cloud_proxy_and_500mbpsattacker_withattacker
  - cloud_proxy_and_500mbpsattacker_withattacker_dtlson
  - cloud_proxy_and_500mbpsattacker_withattacker_dtlson_httpson
  - cloud_proxy_and_500mbpsattacker_withattacker_httpson
  - cloud_proxy_and_attacker_noattacker
  - cloud_proxy_and_attacker_noattacker_dtlson
  - cloud_proxy_and_attacker_noattacker_dtlson_httpson
  - cloud_proxy_and_attacker_noattacker_httpson
  - cloud_proxy_and_attacker_withattacker
  - cloud_proxy_and_attacker_withattacker_dtlson
  - cloud_proxy_and_attacker_withattacker_dtlson_httpson
- **multiclient**: Experiments with fixed attack rate that vary network protocols and number of proxy-server connections.
  - multiclient_cloud_500mbps_attack_noattacker
  - multiclient_cloud_500mbps_attack_noattacker_dtlson
  - multiclient_cloud_500mbps_attack_noattacker_dtlson_httpson
  - multiclient_cloud_500mbps_attack_noattacker_httpson
  - multiclient_cloud_500mbps_attack_withattacker
  - multiclient_cloud_500mbps_attack_withattacker_dtlson
  - multiclient_cloud_500mbps_attack_withattacker_dtlson_100conns
  - multiclient_cloud_500mbps_attack_withattacker_dtlson_httpson
  - multiclient_cloud_500mbps_attack_withattacker_httpson
- **gigabit**: Experiments of 1 Gbps of attack with increasing attack durations, with packet captures enabled and disabled.
  - gigabit_attack_100sec_with_tcpdump
  - gigabit_attack_100sec_without_tcpdump
  - gigabit_attack_20sec_with_tcpdump
  - gigabit_attack_35sec_with_tcpdump
  - gigabit_attack_50sec_with_tcpdump
  - gigabit_attack_50sec_without_tcpdump
  - gigabit_attack_75sec_with_tcpdump

## Downloading Raw Experiment Data

Experiment data does not come with the `git` repository due to storage constraints. To download the experiment data, invoke the [`download-experiments.sh`]() script **from the experiments directory** like below:
```shell
user@server:~/cset-dos-flooding/experiments$ ./download-experiments.sh
```

## Grouping and Processing Experiments

After the download, experiments will be in compressed and unprocessed form. To uncompress and process the experiments, you can make use of the [`set-up-experiments.sh`]() script. It first uncompresses and processes the experiments in groups (and in smaller batches if needed for cpu/memory constraints), and then groups the experiments into the groups mentioned above. 

Note that processing works best on machines with many cores. Additionally, the order of groups and batches specified in [`set-up-experiments.sh`]() assumes that the processing machine **must have at least 48GB of free RAM**. For machines with less RAM, re-order the groupings to have have fewer experiments per batch.