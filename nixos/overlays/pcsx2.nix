# Overlay: build PCSX2 from git master and apply two defensive patches:
# 1. FiFo.cpp: downgrade FQC=0 assertion to warning (on Linux there's
#    no "Ignore" button — pxAssertRel always aborts)
# 2. iR5900.cpp: NULL-check PSM() in the recompiler block scan (3 sites).
#    vtlb_GetPhyPtr returns NULL for unmapped physical addresses; the
#    block scan must not dereference it → SIGSEGV.
final: prev: {
  pcsx2 = prev.pcsx2.overrideAttrs (old: {
    version = "master-a80b314";
    src = final.fetchFromGitHub {
      owner = "PCSX2";
      repo = "pcsx2";
      rev = "a80b3144bb95fc949208c1fdc0a5ef6cf631433d";
      hash = "sha256-lWbIcrUYc4PJ0jpEpHL0nawZE7ukemuwmnt038CP4RU=";
    };
    postPatch = ''
      substituteInPlace cmake/Pcsx2Utils.cmake \
        --replace-fail 'set(PCSX2_GIT_TAG "")' 'set(PCSX2_GIT_TAG "master-a80b314")'

      # Fix 1: FQC=0 assertion → warning (Linux has no "Ignore" button)
      substituteInPlace pcsx2/FiFo.cpp \
        --replace-fail \
          'pxAssertRel(vif1Regs.stat.FQC != 0, "FQC = 0 on VIF FIFO READ!");' \
          'if (vif1Regs.stat.FQC == 0) DevCon.Warning("FQC = 0 on VIF FIFO READ (continuing)");'

      # Fix 2: NULL-check PSM() in recompiler block scan (3 sites)
      ${final.python3}/bin/python3 -c '
      p = "pcsx2/x86/ix86-32/iR5900.cpp"
      src = open(p).read()

      old1 = "\t\tcpuRegs.code = *(int*)PSM(i);\n"
      new1 = "\t\tvoid* _psm_i = PSM(i);\n\t\tif (!_psm_i)\n\t\t{\n\t\t\ts_nEndBlock = i;\n\t\t\twillbranch3 = 1;\n\t\t\tbreak;\n\t\t}\n\t\tcpuRegs.code = *(int*)_psm_i;\n"
      assert old1 in src, "site 1 not found"
      src = src.replace(old1, new1, 1)

      old2 = "\t\t\tcpuRegs.code = *(u32*)PSM(i);\n"
      new2 = "\t\t\tvoid* _psm_ld = PSM(i);\n\t\t\tif (!_psm_ld)\n\t\t\t\tcontinue;\n\t\t\tcpuRegs.code = *(u32*)_psm_ld;\n"
      assert old2 in src, "site 2 not found"
      src = src.replace(old2, new2, 1)

      old3 = "\t\t\tcpuRegs.code = *(int*)PSM(i - 4);\n"
      new3 = "\t\t\tvoid* _psm_bp = PSM(i - 4);\n\t\t\tif (!_psm_bp)\n\t\t\t\tcontinue;\n\t\t\tcpuRegs.code = *(int*)_psm_bp;\n"
      assert old3 in src, "site 3 not found"
      src = src.replace(old3, new3, 1)

      open(p, "w").write(src)
      print("PSM NULL-check patches applied")
      '
    '';
    buildInputs = (old.buildInputs or []) ++ [ final.rapidyaml ];
  });
}
