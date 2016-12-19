function feat_regFix()
{
  local nuisancefeat="${1}"
  local scriptDir="${2}"
  local epiDir="${3}"
  local epiVoxTot="${4}"
  local te="${5}"
  local numtimepoint="${6}"
  local tr="${7}"
  local dwellTime="${8}"
  local peDirNEW="${9}"
  local fsf="${10}"
  local preprocfeat=preproc.feat

  ###### FEAT registration correction ########################################


  local fsf_regFix="dummy_$(basename ${fsf} .fsf | sed 's/reg//')_regFix.fsf" 
  echo $scriptDir/"${fsf_regFix}"
}

feat_regFix nuisancereg_classic_aroma.feat ~/VossLabMount/Universal_Software/reproc epiDir epiVoxTot 25 180 2 dwellTime peDirNEW ~/VossLabMount/Projects/FAST/nuisancereg_classic_aroma.fsf