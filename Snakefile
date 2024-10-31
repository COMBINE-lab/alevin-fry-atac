from os.path import join
import yaml
if not workflow.overwrite_configfiles:
    configfile: "config.yml"

k = config["k"]
m = config["m"]
thr = config["threshold"]
bin_size = config["bin_size"]
threads =config["threads"]
afa_output_path = config["out_path"]
afa_ind_path = join(afa_output_path, "index")
afa_ind_pref = join(afa_ind_path, f"k={k}_m={m}")

map_output_path = join(afa_output_path, "map_output")
out_dir_k_m = join(map_output_path, f"k{k}_m_{m}")
out_dir_k_m_rem = join(out_dir_k_m, f"bin-size={bin_size}_thr={thr}")
out_rad = join(out_dir_k_m_rem, "map.rad")
out_bed = join(out_dir_k_m_rem, "map.bed")

rule all:
    input:
        f"{afa_ind_pref}.sshash",
        out_rad,
        out_bed

rule run_afa_index:
    input:
        config["ref_genome"]
    output:
        [f"{afa_ind_pref}{x}" for x in [".sshash", ".ectab", ".ctab", ".refinfo", "_cfish.json"]]
    params:
        ind_pref = afa_ind_pref,
        k = k,
        m = m,
        piscem_exec_path = join(config["piscem_path"], "target", "release", "piscem"),
        tmpdir = join(config["tmp_dir"], f"k{k}_m{m}"),
        threads = threads
    shell:
        """
            export TMPDIR={params.tmpdir}
            ulimit -n 2048
            {params.piscem_exec_path} build \
                -s {input} \
                -k {params.k} \
                -m {params.m} \
                -t {params.threads} \
                -o {params.ind_pref} \
                -w {params.tmpdir} \
                --overwrite
        """

rule run_afa_map:
    input:
        read1 = config["read1"],
        read2 = config["read2"],
        barcode = config["barcode"]
    output:
        out_rad
    params:
        threads = threads,
        piscem_exec_path = config["piscem_atac_path"],
        ind_pref = afa_ind_pref,
        k = k,
        m = m,
        thr = thr,
        bin_size = bin_size,
        use_chr = lambda wildcards: "--use-chr" if bin_size == "use_chr" else "",
        out_dir = out_dir_k_m_rem
    shell:
        """
            {params.piscem_exec_path} \
                --index {params.ind_pref} \
                --read1 {input.read1} \
                --read2 {input.read2} \
                --barcode {input.barcode} \
                --output {params.out_dir} \
                --thr {params.thr} \
                --threads {params.threads} \
                {params.use_chr} \
                --bin-size {params.bin_size}
        """

rule run_afa_dedup:
    input:
        rules.run_afa_map.output
    output:
        out_bed
    params:
        map_dir = out_dir_k_m_rem,
        threads = threads,
        afa_dedup_path = config["afa_dedup_path"],
        permit_list_path = config["permit_list_path"],
        piscem_exec_path = join(config["piscem_path"], "target", "release", "piscem"),
        rev_comp = config["rev_comp"]
    shell:
        """
		./bash_scripts/run_piscem_dedup.sh \
            	{params.afa_dedup_path} \
                {params.map_dir} {params.permit_list_path} \
                {params.rev_comp} {params.threads} {params.map_dir}
        """

