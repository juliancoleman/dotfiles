# Overlay: build PCSX2 from git master (includes PR #11734
# "Allow mapping main memory anywhere") and patch two crashes:
# 1. FiFo.cpp: downgrade FQC=0 assertion to warning (on Linux there's
#    no "Ignore" button — pxAssertRel always aborts)
# 2. vtlb.cpp: return a zeroed dummy page instead of NULL from
#    vtlb_GetPhyPtr when the physical address is in the null-handler
#    region. The recompiler dereferences this via PSM(). Returning a
#    zero page makes it read NOP (0x00000000) and continue gracefully
#    instead of SIGSEGV.
# 3. iR5900.cpp: stop the block scan loop when PSM(i) returns NULL
#    instead of reading zeros. This prevents the recompiler from
#    scanning past valid RAM into hardware register space.
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
      # Fix 1: Replace the FQC=0 assertion with a warning so the game
      # continues instead of aborting (on Linux there's no "Ignore" button).
      substituteInPlace pcsx2/FiFo.cpp \
        --replace-fail \
          'pxAssertRel(vif1Regs.stat.FQC != 0, "FQC = 0 on VIF FIFO READ!");' \
          'if (vif1Regs.stat.FQC == 0) DevCon.Warning("FQC = 0 on VIF FIFO READ (continuing)");'
      # Fix 2: vtlb_GetPhyPtr returns NULL for unmapped physical addresses
      # (null-handler region past RAM). The recompiler dereferences this
      # via PSM(). Return a pointer to a zeroed static page instead so it
      # reads NOP (0x00000000) instead of SIGSEGV.
      substituteInPlace pcsx2/vtlb.cpp \
        --replace-fail \
          '__fi void* vtlb_GetPhyPtr(u32 paddr)
{
	if (paddr >= VTLB_PMAP_SZ || vtlbdata.pmap[paddr >> VTLB_PAGE_BITS].isHandler())
		return NULL;
	else
		return reinterpret_cast<void*>(vtlbdata.pmap[paddr >> VTLB_PAGE_BITS].assumePtr() + (paddr & VTLB_PAGE_MASK));
}' \
          '__fi void* vtlb_GetPhyPtr(u32 paddr)
{
	if (paddr >= VTLB_PMAP_SZ)
		return NULL;
	const auto& entry = vtlbdata.pmap[paddr >> VTLB_PAGE_BITS];
	if (entry.isHandler())
	{
		static thread_local u8 dummy_page[VTLB_PAGE_SIZE] = {};
		return reinterpret_cast<void*>(dummy_page + (paddr & VTLB_PAGE_MASK));
	}
	return reinterpret_cast<void*>(entry.assumePtr() + (paddr & VTLB_PAGE_MASK));
}'
      # Fix 3: Stop the block scan loop when PSM(i) returns NULL (unmapped
      # page). Without this, the recompiler scans past valid RAM into
      # hardware register space, reading NOPs from the zero page and
      # producing broken blocks that stall the game.
      substituteInPlace pcsx2/x86/ix86-32/iR5900.cpp \
        --replace-fail \
          'cpuRegs.code = *(int*)PSM(i);' \
          'void* _psm = PSM(i); if (!_psm) { s_nEndBlock = i; willbranch3 = 1; break; } cpuRegs.code = *(int*)_psm;'
    '';
    buildInputs = (old.buildInputs or []) ++ [ final.rapidyaml ];
  });
}
