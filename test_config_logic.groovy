// Test della logica
def testCases = [
    [narrow_peak: true,  macs_model: true,  desc: "Narrow + Model"],
    [narrow_peak: true,  macs_model: false, desc: "Narrow + NoModel"],
    [narrow_peak: false, macs_model: true,  desc: "Broad + Model"],
    [narrow_peak: false, macs_model: false, desc: "Broad + NoModel (TUO CASO)"]
]

testCases.each { test ->
    def params = [
        narrow_peak: test.narrow_peak,
        macs_model: test.macs_model,
        broad_cutoff: 0.1,
        fragment_size: 300
    ]
    
    def args = [
        '--keep-dup all',
        params.narrow_peak ? '' : "--broad --broad-cutoff ${params.broad_cutoff}",
        params.macs_model  ? '' : "--nomodel --extsize ${params.fragment_size} --nolambda --call-summits"
    ].join(' ').trim()
    
    println "\n${test.desc}:"
    println "  narrow_peak=${test.narrow_peak}, macs_model=${test.macs_model}"
    println "  Args: ${args}"
}
