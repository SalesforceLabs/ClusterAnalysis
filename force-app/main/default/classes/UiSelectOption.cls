public class UiSelectOption implements Comparable {
    @AuraEnabled
    public String value {get; set;}
    @AuraEnabled
    public String label {get; set;}

    public UiSelectOption(SelectOption so) {
        this.value = so.getValue();
        this.label = so.getLabel();
    }

    public UiSelectOption(PicklistEntry pe) {
        this.value = pe.getValue();
        this.label = pe.getLabel();
    }

    public UiSelectOption(String value, String label) {
        this.value = value;
        this.label = label;
    }

    public Integer compareTo(Object compareTo){
        UiSelectOption selectOption = (UiSelectOption) compareTo;
        String thisLabel = String.isEmpty(this.label) ? '' : this.label;
        String thatLabel = (selectOption == null) || String.isEmpty(selectOption.label) ? '' : selectOption.label;
        return thisLabel.compareTo(thatLabel);
    } 
}