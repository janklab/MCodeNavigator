function out = getJavaPrivateFieldViaReflection(javaObj, fieldName)

exactClass = javaObj.getClass();

klass = exactClass;
ok = false;
while ~ok
    [out,ok] = getFieldViaClass(javaObj, fieldName, klass);
    if ok
        break;
    end
    if isequal(klass.getName, 'java.lang.Object')
        % Nowhere else to go
        error('Failed getting field %s on class %s via Java reflection', ...
            fieldName, exactClass.getName);
    else
        klass = klass.getSuperclass;
    end
end

end

function [out,ok] = getFieldViaClass(javaObj, fieldName, klass)
fields = klass.getDeclaredFields;
field = [];
for i = 1:numel(fields)
    if isequal(char(fields(i).getName), fieldName)
        field = fields(i);
        break;
    end
end
if isempty(field)
    out = [];
    ok = false;
    return;
end
field.setAccessible(true);
out = field.get(javaObj);
ok = true;
end